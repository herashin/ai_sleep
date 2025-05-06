// lib/screens/record_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/stt_service.dart';
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

  bool _isRecording = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    // 1) 마이크 권한 요청
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    // 2) 레코더 오픈
    await _recorder.openRecorder();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // ■ Stop
      final String? path = await _recorder.stopRecorder();
      setState(() => _isRecording = false);

      if (path == null) return;
      _filePath = path;

      final file = File(path);
      if (!file.existsSync()) return;

      // 1) STT 변환
      final String? transcript = await _sttService.transcribe();
      if (transcript == null) return;

      // 2) GPT 요약
      final String? summary = await _gptService.summarizeText(transcript);

      // 3) 결과 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            originalText: transcript,
            summaryText: summary ?? '요약 실패',
          ),
        ),
      );
    } else {
      // ■ Start
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      setState(() {
        _isRecording = true;
        _filePath = path;
      });
    }
  }

  @override
  void dispose() {
    // 레코더 닫기
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('진료 녹음')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isRecording ? Icons.mic : Icons.mic_none,
                size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleRecording,
              child: Text(_isRecording ? '녹음 중지' : '녹음 시작'),
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 20),
              Text('파일 경로:\n$_filePath', textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
