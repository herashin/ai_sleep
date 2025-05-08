// lib/screens/record_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/stt_service.dart'; // Whisper용
import '../services/gpt_service.dart';
import 'result_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({Key? key}) : super(key: key);
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
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
    // 마이크 권한 요청
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showPermissionDeniedSnackBar();
      return;
    }
    // 녹음기 초기화
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

    if (_isRecording) {
      // ■ Stop recording
      _timer?.cancel();
      final path = await _recorder.stopRecorder();
      await Future.delayed(const Duration(milliseconds: 100));
      if (path == null) return;
      final file = File(path);
      if (!file.existsSync()) return;

      final bytes = file.lengthSync();
      final estimatedSec = bytes / 32000;
      setState(() {
        _isRecording = false;
        _filePath = path;
      });
      if (estimatedSec < 0.1) return;

      setState(() => _isLoading = true);
      try {
        final transcript = await _sttService.transcribeAudio(File(path));
        if (transcript != null) {
          final summary = await _gptService.summarizeText(transcript);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                originalText: transcript,
                summaryText: summary,
                audioPath: path,
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('STT/요약 오류: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // ■ Start recording
      // 외부 저장소 권한 보장 (Android11+)
      final ok = await _ensureManageExternalStorage();
      if (!ok) {
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

      // 공용 외부 폴더 경로
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
              onPressed:
                  (!_recorderReady || _isLoading) ? null : _toggleRecording,
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
