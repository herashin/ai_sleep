// lib/screens/record_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/stt_service.dart'; // Whisper용
import '../services/gpt_service.dart';
import 'result_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({Key? key}) : super(key: key);
  @override
  RecordScreenState createState() => RecordScreenState();
}

class RecordScreenState extends State<RecordScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final STTService _sttService = STTService();
  final GPTService _gptService = GPTService();

  Timer? _timer;
  int _elapsedMs = 0;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _recorderReady = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showPermissionDeniedSnackBar();
      return;
    }
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorder.onProgress!.listen((event) {
      if (mounted) setState(() => _elapsedMs = event.duration.inMilliseconds);
    });
    setState(() => _recorderReady = true);
  }

  void _showPermissionDeniedSnackBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다.')),
      );
    });
  }

  Future<bool> _ensureManageExternalStorage() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      }
    }
    return true;
  }

  Future<void> _toggleRecording() async {
    if (_isLoading || !_recorderReady) return;

    // 마이크 권한이 거부된 상태라면 다시 요청
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final req = await Permission.microphone.request();
      if (!req.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한이 필요합니다.')),
        );
        return;
      }
    }

    if (_isRecording) {
      // ■ Stop recording
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

      setState(() => _isLoading = true);
      try {
        final transcript = await _sttService.transcribeAudio(File(tempPath));
        if (transcript == null) return;
        final summary = await _gptService.summarizeText(transcript);
        final patientName = (await _gptService.extractPatientName(transcript))
                ?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_')
                .trim() ??
            'unknown';

        // 파일명 및 메타 저장
        final pubDir = Directory('/storage/emulated/0/AI_Sleep');
        if (!pubDir.existsSync()) pubDir.createSync(recursive: true);
        final baseName =
            'consult_${patientName}_${DateTime.now().millisecondsSinceEpoch}';
        final newAudioPath = '${pubDir.path}/$baseName.m4a';
        final newMetaPath = '${pubDir.path}/$baseName.json';

        await file.rename(newAudioPath);
        final meta = {
          'originalText': transcript,
          'summaryText': summary,
          'createdAt': DateTime.now().toIso8601String(),
          'patientName': patientName,
        };
        await File(newMetaPath).writeAsString(jsonEncode(meta));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              originalText: transcript,
              summaryText: summary,
              audioPath: newAudioPath,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('STT/요약 오류: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // ■ Start recording
      final ok = await _ensureManageExternalStorage();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 파일 접근 권한이 필요합니다.')),
        );
        return;
      }

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
        _timer = Timer.periodic(
          const Duration(milliseconds: 100),
          (t) {
            if (!_isRecording) {
              t.cancel();
              return;
            }
            setState(() => _elapsedMs += 100);
          },
        );
      } catch (e) {
        setState(() => _isRecording = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('녹음 시작 실패: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_recorder.isRecording) _recorder.stopRecorder();
    _recorder.closeRecorder();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onPressed: _isLoading
                  ? null
                  : () async {
                      // 1) 마이크 권한 재요청
                      final micStatus = await Permission.microphone.status;

                      // 2) 영구 거부(permanentlyDenied) 상태면 설정 화면으로 이동
                      if (micStatus.isPermanentlyDenied) {
                        await openAppSettings();
                        return;
                      }
                      // 3) 아직 허용 안 된 상태면 다시 요청
                      if (!micStatus.isGranted) {
                        final req = await Permission.microphone.request();
                        if (!req.isGranted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('마이크 권한이 필요합니다.')),
                          );
                          return;
                        }
                      }
                      // 4) 녹음기 초기화가 안 됐다면 초기화 실행
                      if (!_recorderReady) {
                        await _initRecorder();
                        if (!_recorderReady) return; // 여전히 권한 없으면 중단
                      }
                      // 5) 녹음 토글
                      await _toggleRecording();
                    },
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
    );
  }
}
