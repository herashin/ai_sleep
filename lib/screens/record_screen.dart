// lib/screens/record_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/permission_gate.dart';
import '../services/stt_service.dart';
import '../services/gpt_service.dart';
import '../models/recording.dart';
import '../models/summary_item.dart'; // ← 추가
import 'result_screen.dart';
import '../services/emoji_assets.dart';

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

  Future _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorder.onProgress?.listen((event) {
      if (mounted) setState(() => _elapsedMs = event.duration.inMilliseconds);
    });
    setState(() => _recorderReady = true);
  }

  Future _toggleRecording() async {
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
        // 1) STT
        final rawTranscript = await _sttService.transcribeAudio(file);
        if (rawTranscript == null) throw Exception('음성 인식에 실패했습니다.');

        // 2) GPT 요약 + 아이콘
        final result = await _gptService.reviseAndSummarize(rawTranscript);
        final cleanedTranscript = result.cleanedText;
        final summary = result.summary; // 요약 텍스트(String)
        final summaryIcons = result.summaryIcons; // 아이콘 키(List<String>)

        if (summary.isEmpty) throw Exception('GPT 요약에 실패했습니다.');

        // 3) 환자명 추출
        final nameRaw = await _gptService.extractPatientName(cleanedTranscript);
        final patientName =
            (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_').trim()) ??
                'unknown';

        // 4) 파일 이동 및 메타 저장 준비
        final pubDir = Directory('/storage/emulated/0/AI_Sleep');
        if (!pubDir.existsSync()) pubDir.createSync(recursive: true);
        final baseName =
            'consult_${patientName}_${DateTime.now().millisecondsSinceEpoch}';
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

        // 6) Recording 객체 생성 (모델에도 summaryItems 필드 추가 필요)
        final recording = Recording(
          audioPath: newAudioPath,
          originalText: cleanedTranscript,
          summaryItems: summaryItems, // 새로운 필드
          createdAt: DateTime.now(),
          patientName: patientName,
        );

        // 7) 메타 JSON 저장
        await File(newMetaPath).writeAsString(
          jsonEncode(recording.toJson()),
          encoding: utf8,
        );

        // 8) 결과 화면으로 이동
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(recording: recording),
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
      // 녹음 시작
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('녹음 시작 실패: ${e.toString()}')),
          );
        }
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
