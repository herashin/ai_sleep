// lib/screens/record_screen.dart

import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../services/gpt_service.dart';
import 'result_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({Key? key}) : super(key: key);

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final STTService _sttService = STTService();
  final GPTService _gptService = GPTService();

  bool _isRecording = false;
  bool _isLoading = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _sttService.init(); // 권한 요청 및 초기화
  }

  Future<void> _toggleRecording() async {
    if (_isLoading) return;

    if (_isRecording) {
      // ■ Stop listening
      await _sttService.stopListening();
      setState(() {
        _isRecording = false;
        _recognizedText = _sttService.recognizedText; // 결과 복사
      });

      // 인식된 텍스트가 없으면 종료
      if (_recognizedText.isEmpty) return;

      // ■ GPT 요약
      setState(() => _isLoading = true);
      final summary = await _gptService.summarizeText(_recognizedText);
      setState(() => _isLoading = false);

      // ■ 결과 화면 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            originalText: _recognizedText,
            summaryText: summary,
          ),
        ),
      );
    } else {
      // ■ Start listening
      setState(() {
        _isRecording = true;
        _recognizedText = '';
      });
      await _sttService.startListening();
    }
  }

  @override
  void dispose() {
    _sttService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('진료 녹음 (네이티브 STT)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 80,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleRecording,
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    )
                  : Text(_isRecording ? '인식 중지' : '인식 시작'),
            ),
            if (!_isRecording && _recognizedText.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '인식된 텍스트:\n$_recognizedText',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
