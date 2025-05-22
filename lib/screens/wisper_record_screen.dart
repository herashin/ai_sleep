import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/recording.dart';
import '../models/summary_item.dart';
import '../services/stt_service.dart';
import '../services/gpt_service.dart';
import '../widgets/permission_gate.dart';
import 'result_screen.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class PermissionHelper {
  bool _requestInProgress = false;

  Future<bool> checkAndRequestPermissions({
    bool requireMicrophone = false,
    bool requireStorage = false,
  }) async {
    if (_requestInProgress) return false;
    _requestInProgress = true;

    if (requireMicrophone) {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          _requestInProgress = false;
          return false;
        }
      }
    }

    if (requireStorage) {
      final granted = await _requestStoragePermission();
      if (!granted) {
        _requestInProgress = false;
        return false;
      }
    }

    _requestInProgress = false;
    return true;
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdk = androidInfo.version.sdkInt;

    if (sdk >= 30) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({Key? key}) : super(key: key);

  @override
  RecordScreenState createState() => RecordScreenState();
}

class RecordScreenState extends State<RecordScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final STTService _sttService = STTService();
  final GPTService _gptService = GPTService();
  final PermissionHelper _permissionHelper = PermissionHelper();

  StreamSubscription? _recorderSub;
  Timer? _timer;
  int _elapsedMs = 0;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _recorderReady = false;
  String? _filePath;

  List<Map<String, dynamic>> _dialogues = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndRedirect();
      await _initRecorder();
    });
  }

  Future<void> _checkPermissionsAndRedirect() async {
    final microphoneStatus = await Permission.microphone.status;
    final storageStatus = await Permission.manageExternalStorage.status;

    if (!microphoneStatus.isGranted || !storageStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한이 없으면 녹음 기능을 사용할 수 없습니다.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSub = _recorder.onProgress?.listen((event) {
      if (mounted) setState(() => _elapsedMs = event.duration.inMilliseconds);
    });
    if (!mounted) return;
    setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
    if (_isLoading || !_recorderReady) return;

    bool granted = await _permissionHelper.checkAndRequestPermissions(
      requireMicrophone: true,
      requireStorage: true,
    );
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필요한 권한이 허용되어야 합니다.')),
      );
      return;
    }

    if (_isRecording) {
      _timer?.cancel();
      final tempPath = await _recorder.stopRecorder();
      await Future.delayed(const Duration(milliseconds: 100));
      if (tempPath == null) return;
      final file = File(tempPath);
      if (!file.existsSync()) return;

      setState(() {
        _isRecording = false;
        _filePath = tempPath;
      });
      await _processRecording(file);
    } else {
      setState(() {
        _isRecording = true;
        _elapsedMs = 0;
        _filePath = null;
        _dialogues = [];
      });

      final dir = Directory('/storage/emulated/0/AI_Sleep');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final outPath =
          '${dir.path}/consult_${DateTime.now().millisecondsSinceEpoch}.m4a';

      try {
        await _recorder.startRecorder(
          toFile: outPath,
          codec: Codec.aacMP4,
          sampleRate: 16000,
          numChannels: 1,
        );
        _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          if (!_isRecording) {
            t.cancel();
            return;
          }
          if (mounted) setState(() => _elapsedMs += 100);
        });
      } catch (e) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('녹음 실패: $e')));
      }
    }
  }

  Future<String> _convertAudioFormat(String inputPath) async {
    final outputPath = inputPath.replaceAll(RegExp(r'\.\w+$'), '.wav');
    final command = '-i "$inputPath" -ar 16000 -ac 1 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      throw Exception('FFmpeg 변환 실패 코드: $returnCode');
    }
  }

  Future<void> _processRecording(File file) async {
    setState(() => _isLoading = true);
    try {
      // 1) FFmpeg 변환
      final convertedPath = await _convertAudioFormat(file.path);
      final convertedFile = File(convertedPath);

      // 2) STT + Diarize API 호출 (Docker 백엔드)
      final rawJson =
          await _sttService.transcribeAudioWithSegments(convertedFile);
      if (rawJson == null) throw Exception('음성 인식 실패');

      // 3) 서버가 돌려준 dialogues 사용
      final serverDialogues =
          (rawJson['dialogues'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _dialogues = serverDialogues;
      });

      // 4) GPT 요약
      final summary =
          await _gptService.summarizeText(rawJson['text'] as String);
      if (summary == null) throw Exception('GPT 요약 실패');

      // 5) 환자명 추출, 파일 이동 및 메타 저장
      final nameRaw =
          await _gptService.extractPatientName(rawJson['text'] as String);
      final patientName =
          (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_') ?? 'unknown')
              .trim();
      final dir = Directory('/storage/emulated/0/AI_Sleep');
      final base =
          'consult_${patientName}_${DateTime.now().millisecondsSinceEpoch}';
      final audioPath = '${dir.path}/$base.m4a';
      final metaPath = '${dir.path}/$base.json';

      await file.rename(audioPath);

      final lines = summary
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final summaryItems =
          lines.map((l) => SummaryItem(iconCode: '', text: l)).toList();

      final rec = Recording(
        audioPath: audioPath,
        originalText: rawJson['text'] as String,
        summaryItems: summaryItems,
        createdAt: DateTime.now(),
        patientName: patientName,
        speakers: serverDialogues
            .map((d) => {
                  'speaker': d['speaker'],
                  'start': d['start'],
                  'end': d['end'],
                })
            .toList(),
        dialogues: serverDialogues,
      );

      await File(metaPath)
          .writeAsString(jsonEncode(rec.toJson()), encoding: utf8);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(initialRecording: rec)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _recorderSub?.cancel();
    _timer?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      requireMicrophone: true,
      requireStorage: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('상담 녹음')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 80,
                color: _isRecording ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text('녹음 시간: ${(_elapsedMs / 1000).toStringAsFixed(1)}초'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    (_isLoading || !_recorderReady) ? null : _toggleRecording,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text(_isRecording ? '녹음 중지' : '녹음 시작'),
              ),
              if (_filePath != null) ...[
                const SizedBox(height: 12),
                Text('파일 저장: $_filePath', textAlign: TextAlign.center),
              ],
              if (_dialogues.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('화자별 대화 내용',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _dialogues.length,
                    itemBuilder: (context, index) {
                      final d = _dialogues[index];
                      return ListTile(
                        title: Text('[${d["speaker"]}] ${d["text"]}'),
                        subtitle: Text(
                            '(${d["start"].toStringAsFixed(2)}~${d["end"].toStringAsFixed(2)}초)'),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
