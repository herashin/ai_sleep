// lib/screens/record_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/permission_gate.dart'; // PermissionGate import
import '../services/stt_service.dart';
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
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorder.onProgress!.listen((event) {
      if (mounted) setState(() => _elapsedMs = event.duration.inMilliseconds);
    });
    setState(() => _recorderReady = true);
  }

  Future<void> _toggleRecording() async {
    if (_isLoading || !_recorderReady) return;

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

      setState(() => _isLoading = true);
      try {
        // 1) STT 변환
        final transcript = await _sttService.transcribeAudio(File(tempPath));
        if (transcript == null) throw Exception('음성 인식에 실패했습니다.');
        // 2) 요약
        final summaryNullable = await _gptService.summarizeText(transcript);
        if (summaryNullable == null) throw Exception('AI 요약에 실패했습니다.');
        final summary = summaryNullable;
        // 3) 환자명 추출
        final patientNameNullable =
            await _gptService.extractPatientName(transcript);
        final patientName = (patientNameNullable
                ?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_')
                .trim()) ??
            'unknown';

        // 파일 저장 준비 및 이동
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
              patientName: patientName,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
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
          setState(() => _elapsedMs += 100);
        });
      } catch (e) {
        setState(() => _isRecording = false);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('녹음 시작 실패: ${e.toString()}')),
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
