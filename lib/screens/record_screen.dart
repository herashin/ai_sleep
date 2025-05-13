// lib/screens/record_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/permission_gate.dart';
import '../services/stt_service.dart';
import '../services/gpt_service.dart';
import '../models/recording.dart';
import '../models/summary_item.dart';
import '../widgets/gpt_quota_gate.dart';
import 'result_screen.dart';
import '../services/emoji_assets.dart';

Future<bool> ensureManageStoragePermission() async {
  // 먼저 권한 상태를 정확히 확인
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
    ensureManageStoragePermission();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSub = _recorder.onProgress?.listen((event) {
      if (mounted) {
        setState(() {
          _elapsedMs = event.duration.inMilliseconds;
        });
      }
    });
    if (!mounted) return;
    setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
    final hasManageStoragePermission = await ensureManageStoragePermission();
    final hasMicrophonePermission = await Permission.microphone.isGranted;

    if (!hasManageStoragePermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 접근 권한이 필요합니다. 설정에서 허용해주세요.')),
      );
      return;
    }

    if (!hasMicrophonePermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다. 설정에서 허용해주세요.')),
      );
      return;
    }

    if (_isLoading || !_recorderReady) return;

    if (_isRecording) {
      // 기존 녹음 중지 로직 그대로 유지
      _timer?.cancel();
      final tempPath = await _recorder.stopRecorder();
      await Future.delayed(const Duration(milliseconds: 100));
      if (tempPath == null) return;

      final file = File(tempPath);
      if (!file.existsSync()) return;

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _filePath = tempPath;
      });

      await _processRecording(file);
    } else {
      // 기존 녹음 시작 로직 그대로 유지
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _elapsedMs = 0;
        _filePath = null;
      });

      final pubDir = Directory('/storage/emulated/0/AI_Sleep');
      if (!pubDir.existsSync()) pubDir.createSync(recursive: true);
      final outPath =
          '${pubDir.path}/consult_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
        if (mounted) setState(() => _isRecording = false);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('녹음 시작 실패: $e')));
        }
      }
    }
  }

  Future<void> _processRecording(File file) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // 1) STT
      final rawTranscript = await _sttService.transcribeAudio(file);
      if (rawTranscript == null) throw Exception('음성 인식에 실패했습니다.');

      // 2) GPT 요약
      final result = await _gptService.reviseAndSummarize(rawTranscript);
      final cleanedTranscript = result.cleanedText;
      final summary = result.summary;
      final summaryIcons = result.summaryIcons;
      if (summary.isEmpty) throw Exception('GPT 요약에 실패했습니다.');

      // 3) 환자명 추출
      final nameRaw = await _gptService.extractPatientName(cleanedTranscript);
      final patientName =
          (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_').trim()) ??
              'unknown';

      // 4) 파일 이동 및 메타 저장
      final pubDir = Directory('/storage/emulated/0/AI_Sleep');
      final baseName =
          'consult_\$patientName_${DateTime.now().millisecondsSinceEpoch}';
      final newAudioPath = '${pubDir.path}/$baseName.m4a';
      final newMetaPath = '${pubDir.path}/$baseName.json';
      await file.rename(newAudioPath);

      // 5) SummaryItem 리스트 생성
      final lines =
          summary.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final summaryItems = List<SummaryItem>.generate(
        summaryIcons.length,
        (i) => SummaryItem(
          iconCode: summaryIcons[i],
          text: i < lines.length ? lines[i] : '',
        ),
      );

      // 6) Recording 객체
      final recording = Recording(
        audioPath: newAudioPath,
        originalText: cleanedTranscript,
        summaryItems: summaryItems,
        createdAt: DateTime.now(),
        patientName: patientName,
      );

      // 7) JSON 저장
      await File(newMetaPath).writeAsString(
        jsonEncode(recording.toJson()),
        encoding: utf8,
      );

      // 8) 결과 화면 이동
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(recording: recording),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _recorderSub?.cancel();
    if (_recorder.isRecording) _recorder.stopRecorder();
    _recorder.closeRecorder();
    _timer?.cancel();
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
