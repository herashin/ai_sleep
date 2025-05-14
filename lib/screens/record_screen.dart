// lib/screens/record_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/recording.dart';
import '../models/summary_item.dart';
import '../services/stt_service.dart';
import '../services/gpt_service.dart';
import '../widgets/permission_gate.dart';
import 'result_screen.dart';

Future<bool> ensureManageStoragePermission() async {
  final status = await Permission.manageExternalStorage.status;
  if (status.isGranted) {
    debugPrint('✅ 모든 파일 접근 권한이 이미 허용되어 있습니다.');
    return true;
  } else {
    debugPrint('🚩 모든 파일 접근 권한을 요청합니다.');
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
  final STTService _sttService = STTService();
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
    // 화면 렌더링 후 권한 및 recorder 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ensureManageStoragePermission();
      await _initRecorder();
    });
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSub = _recorder.onProgress?.listen((event) {
      if (mounted) {
        setState(() => _elapsedMs = event.duration.inMilliseconds);
      }
    });
    if (!mounted) return;
    setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
    final hasStorage = await ensureManageStoragePermission();
    final hasMic = await Permission.microphone.isGranted;

    if (!hasStorage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 접근 권한이 필요합니다.')),
      );
      return;
    }
    if (!hasMic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다.')),
      );
      return;
    }
    if (_isLoading || !_recorderReady) return;

    if (_isRecording) {
      // 중지
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
      // 시작
      setState(() {
        _isRecording = true;
        _elapsedMs = 0;
        _filePath = null;
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

  Future<void> _processRecording(File file) async {
    setState(() => _isLoading = true);
    try {
      // 1) STT
      final raw = await _sttService.transcribeAudio(file);
      if (raw == null) throw Exception('음성 인식 실패');

      // 2) GPT 요약(다듬기 + 이모지 태그)
      var result = await _gptService.reviseAndSummarize(raw);
      var summary = result.summary;
      if (summary.isEmpty) {
        final fallback = await _gptService.summarizeText(raw);
        summary = fallback ?? '';
      }
      if (summary.isEmpty) throw Exception('GPT 요약 실패');

      // 3) 환자명 추출
      final nameRaw = await _gptService.extractPatientName(raw);
      final patientName =
          (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_').trim()) ??
              'unknown';

      // 4) 파일 이동 & 메타 저장 준비
      final dir = Directory('/storage/emulated/0/AI_Sleep');
      final base =
          'consult_${patientName}_${DateTime.now().millisecondsSinceEpoch}';
      final audioPath = '${dir.path}/$base.m4a';
      final metaPath = '${dir.path}/$base.json';
      await file.rename(audioPath);

      // 5) SummaryItem 리스트 생성 (iconCode 채우기)
      final lines = summary
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final icons = result.summaryIcons; // ['1f4dd', '1f332', …]
      final summaryItems = List<SummaryItem>.generate(
        lines.length,
        (i) => SummaryItem(
          iconCode: i < icons.length ? icons[i] : '',
          text: lines[i],
        ),
      );

      // 6) Recording 객체 & JSON 저장
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

      // 7) 결과 화면으로 이동
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(initialRecording: rec)),
      );
    } catch (e) {
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
