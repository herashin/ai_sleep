import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import '../models/recording.dart';
import '../models/summary_item.dart';
import '../services/google_stt_service.dart';
import '../services/gpt_service.dart';
import '../widgets/permission_gate.dart';
import 'result_screen.dart';

const String audioExtension = 'aac';
const Codec audioCodec = Codec.aacADTS;
String getSttEncoding() => 'FLAC';

Future<File> convertToWav(File inputFile) async {
  final dir = inputFile.parent.path;
  final fileNameWithoutExt = inputFile.uri.pathSegments.last.split('.').first;
  final wavPath = '$dir/${fileNameWithoutExt}_converted.flac';

  // final command =
  //   '-y -i "${inputFile.path}" -ar 16000 -ac 1 -sample_fmt s16 "$wavPath"';
  final command =
      '-y -i "${inputFile.path}" -af "afftdn=nf=-25" -ar 16000 -ac 1 -sample_fmt s16 -c:a flac "$wavPath"';

  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();

  if (returnCode?.isValueSuccess() == true) {
    debugPrint('✅ FFmpeg 변환 성공: $wavPath');
    return File(wavPath);
  } else {
    debugPrint('❌ FFmpeg 변환 실패: ${await session.getAllLogsAsString()}');
    throw Exception('FFmpeg 변환 실패');
  }
}

Future<bool> ensureManageStoragePermission() async {
  final status = await Permission.manageExternalStorage.status;
  if (status.isGranted) return true;
  if (await Permission.manageExternalStorage.isPermanentlyDenied ||
      await Permission.manageExternalStorage.isDenied) {
    return false;
  }
  final result = await Permission.manageExternalStorage.request();
  return result.isGranted;
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({Key? key}) : super(key: key);

  @override
  RecordScreenState createState() => RecordScreenState();
}

class RecordScreenState extends State<RecordScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final GoogleSTTService _sttService = GoogleSTTService();
  final GPTService _gptService = GPTService();

  StreamSubscription? _recorderSub;
  Timer? _timer;
  int _elapsedMs = 0;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _recorderReady = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ensureManageStoragePermission();
      await _initRecorder();
    });
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSub = _recorder.onProgress?.listen((event) {
      final ms = event.duration.inMilliseconds;
      if (mounted) setState(() => _elapsedMs = ms);
    });
    if (mounted) setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
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
      });

      final dir = Directory('/storage/emulated/0/AI_Sleep');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final outPath =
          '${dir.path}/consult_${DateTime.now().millisecondsSinceEpoch}.$audioExtension';

      try {
        await _recorder.startRecorder(
          toFile: outPath,
          codec: audioCodec,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 192000,
        );
        _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          if (!_isRecording) t.cancel();
          if (mounted) setState(() => _elapsedMs += 100);
        });
      } catch (e) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('녹음 실패: $e')));
      }
    }
  }

  Future<void> _processRecording(File file) async {
    final wavFile = await convertToWav(file);
    final raw = await _sttService.transcribeViaGCS(wavFile, 'ai_sleep');

    setState(() => _isLoading = true);
    try {
      debugPrint('📄 STT 결과: $raw');
      if (raw == null || raw.trim().isEmpty) throw Exception('음성 인식 실패');

      final summaryText = await _gptService.summarizeText(raw);
      final lines = summaryText
              ?.split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList() ??
          [];

      final icons = lines
          .map((l) => RegExp(r'\[(.*?)\]').firstMatch(l)?.group(1) ?? '')
          .toList();

      final summaryItems = List<SummaryItem>.generate(
        lines.length,
        (i) => SummaryItem(
          iconCode: icons[i],
          text: lines[i].replaceAll(RegExp(r'\[.*?\]\s*'), ''),
        ),
      );

      final nameRaw = await _gptService.extractPatientName(raw);
      final patientName =
          (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_').trim()) ??
              'unknown';

      final dir = Directory('/storage/emulated/0/AI_Sleep');
      final base =
          'consult_${patientName}_${DateTime.now().millisecondsSinceEpoch}.$audioExtension';
      final audioPath = '${dir.path}/$base';
      final metaPath = '${dir.path}/$base.json';
      await file.rename(audioPath);

      final rec = Recording(
        audioPath: audioPath,
        originalText: raw,
        summaryItems: summaryItems,
        createdAt: DateTime.now(),
        patientName: patientName,
      );
      await File(metaPath)
          .writeAsString(jsonEncode(rec.toJson()), encoding: utf8);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(initialRecording: rec)),
      );
    } catch (e, stack) {
      debugPrint('🧨 예외 발생: $e');
      debugPrint(stack.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
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
            ],
          ),
        ),
      ),
    );
  }
}
