import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/recording.dart';
import '../models/summary_item.dart';
import '../services/google_stt_service.dart';
import '../services/gpt_service.dart';
import '../widgets/permission_gate.dart';
import 'result_screen.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

// === 🔧 설정 상수 (확장자 및 코덱 전역 관리용) ===
const String audioExtension = 'aac'; // 바꾸려면 'aac', 'mp3' 등으로
const Codec audioCodec = Codec.aacADTS; // 바꾸려면 Codec.aacADTS, Codec.mp3 등으로

// STT encoding 매핑 함수
String getSttEncoding() {
  switch (audioExtension) {
    case 'wav':
      return 'LINEAR16';
    case 'mp3':
      return 'MP3';
    case 'flac':
      return 'FLAC';
    case 'aac':
      return 'ENCODING_UNSPECIFIED';
    default:
      return 'ENCODING_UNSPECIFIED';
  }
}

// 🎛️ FFmpeg 변환 함수 추가
Future<File> convertToWav(File inputFile) async {
  final dir = inputFile.parent.path;
  final fileNameWithoutExt = inputFile.uri.pathSegments.last.split('.').first;
  final wavPath = '$dir/${fileNameWithoutExt}_converted.wav';

  final command =
      '-y -i "${inputFile.path}" -ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"';

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

// 🧩 사용 시점 예시 (RecordScreen._processRecording 내부)
// File wavFile = await convertToWav(file);
// final raw = await _sttService.transcribe(wavFile, getSttEncoding());

Future<bool> ensureManageStoragePermission() async {
  final status = await Permission.manageExternalStorage.status;

  if (status.isGranted) {
    debugPrint('✅ 모든 파일 접근 권한이 이미 허용되어 있습니다.');
    return true;
  } else {
    debugPrint('🚩 모든 파일 접근 권한을 요청합니다.');

    // 이미 요청 중이면 오류가 발생하므로 status 확인만 하고, request는 하지 않음
    if (await Permission.manageExternalStorage.isPermanentlyDenied ||
        await Permission.manageExternalStorage.isDenied) {
      return false; // 거부 상태면 false만 반환하고 요청은 하지 않음
    }

    final result = await Permission.manageExternalStorage.request();
    debugPrint('✅ 권한 요청 결과: $result');
    return result.isGranted;
  }
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
      debugPrint('🎙️ 녹음 중... ${ms}ms');
      if (mounted) setState(() => _elapsedMs = ms);
    });
    if (!mounted) return;
    setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
    /*
    if (_isLoading || !_recorderReady) return;

    final micGranted = await Permission.microphone.isGranted;
    final storageGranted = await Permission.manageExternalStorage.isGranted;

    if (!micGranted || !storageGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한 허용 후 다시 시도해주세요')),
      );
      return;
    }
    */

    // ⬇ 이하 기존 로직 유지
    if (_isRecording) {
      _timer?.cancel();
      final tempPath = await _recorder.stopRecorder();
      debugPrint('🛑 Recorder stopped, saved to: $tempPath');
      debugPrint('📏 Duration: ${_elapsedMs / 1000}초');
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
        debugPrint('🎙️ 녹음 시작: $outPath');
        await _recorder.startRecorder(
          toFile: outPath,
          codec: audioCodec,
          sampleRate: 16000,
          numChannels: 1,
        );
        debugPrint('✅ Recorder started');
        debugPrint('🎙️ isRecording: ${await _recorder.isRecording}');
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

  Future<void> _processRecording(File file) async {
    // 🔄 변환: mp3 → wav
    final wavFile = await convertToWav(file);

// 🧠 음성 텍스트 변환 요청 (변환된 .wav 파일 사용)
    final raw = await _sttService.transcribe(wavFile, getSttEncoding());
    setState(() => _isLoading = true);
    try {
      debugPrint('📤 STT 전송 파일: ${wavFile.path}');
      debugPrint('📦 파일 크기: ${wavFile.lengthSync()} bytes');

      // 1) STT
      //    final raw = await _sttService.transcribe(file, getSttEncoding());

      debugPrint('📄 STT 결과: $raw');
      if (raw == null || raw.trim().isEmpty) throw Exception('음성 인식 실패');

      // 2) GPT 요약
      debugPrint('🤖 GPT 요약 요청 시작...');
      final summaryText = await _gptService.summarizeText(raw);
      debugPrint('📝 GPT 요약 결과:\n$summaryText');
      if (summaryText == null || summaryText.isEmpty) {
        throw Exception('GPT 요약 실패');
      }

      final lines = summaryText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

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

      // 3) 환자명 추출
      debugPrint('🔍 환자명 추출 요청...');
      final nameRaw = await _gptService.extractPatientName(raw);
      final patientName =
          (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_').trim()) ??
              'unknown';
      debugPrint('🧑‍⚕️ 추출된 환자명: $patientName');

      // 4) 파일 이동 & 메타 저장
      final dir = Directory('/storage/emulated/0/AI_Sleep');
      final base =
          'consult_${patientName}_${DateTime.now().millisecondsSinceEpoch}.$audioExtension';
      final audioPath = '${dir.path}/$base';
      final metaPath = '${dir.path}/$base.json';
      await file.rename(audioPath);
      debugPrint('📁 파일 저장 완료: $audioPath');

      final rec = Recording(
        audioPath: audioPath,
        originalText: raw,
        summaryItems: summaryItems,
        createdAt: DateTime.now(),
        patientName: patientName,
      );
      await File(metaPath).writeAsString(
        jsonEncode(rec.toJson()),
        encoding: utf8,
      );
      debugPrint('🗃️ 메타 정보 저장 완료: $metaPath');

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
