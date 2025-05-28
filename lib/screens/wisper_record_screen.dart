import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../models/recording.dart';
import '../models/summary_item.dart';
import '../services/stt_service.dart';
import '../services/gpt_service.dart';
import '../widgets/permission_gate.dart';
import '../widgets/recording_control.dart';
import '../widgets/recording_timer.dart';
import '../widgets/file_info_display.dart';
import '../widgets/dialogues_list.dart';
import '../utils/logger.dart';
import 'result_screen.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class WhisperRecordScreen extends StatefulWidget {
  const WhisperRecordScreen({Key? key}) : super(key: key);

  @override
  WhisperRecordScreenState createState() => WhisperRecordScreenState();
}

class WhisperRecordScreenState extends State<WhisperRecordScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final STTService _sttService = STTService();
  final GPTService _gptService = GPTService();
  bool _isRecording = false;
  bool _isLoading = false;
  bool _recorderReady = false;
  int _selectedSpeakers = 2;
  int _elapsedMs = 0;
  String? _filePath;
  List<Map<String, dynamic>> _dialogues = [];
  StreamSubscription? _recorderSub;
  Timer? _timer;
  String? _loadingMessage; // 로딩스피너 상태문구

  @override
  void initState() {
    super.initState();
    _initLogger();
    _initRecorder();
  }

  Future<void> _initLogger() async {
    try {
      await Logger().init();
      await Logger().log('WhisperRecordScreen 진입, 로그파일 초기화');
      print('Logger 초기화 완료');
    } catch (e) {
      print('Logger 초기화 실패: $e');
    }
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSub = _recorder.onProgress?.listen((event) {
      if (mounted) setState(() => _elapsedMs = event.duration.inMilliseconds);
    });
    if (mounted) setState(() => _recorderReady = true);
    print('녹음기 준비 완료');
  }

  Future<void> _toggleRecording() async {
    if (_isLoading || !_recorderReady) return;
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      await _startRecording();
    } else {
      await _stopRecording();
    }
  }

  Future<void> _startRecording() async {
    final dir = Directory('/storage/emulated/0/AI_Sleep');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final outPath =
        '${dir.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await Logger().log('녹음 시작: $outPath');
    print('녹음 시작: $outPath');
    await _recorder.startRecorder(
      toFile: outPath,
      codec: Codec.aacMP4,
      sampleRate: 16000,
      numChannels: 1,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!_isRecording) t.cancel();
      if (mounted) setState(() => _elapsedMs += 100);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stopRecorder();
    if (path != null) {
      setState(() => _filePath = path);
      await Logger().log('녹음 종료: $path');
      print('녹음 종료: $path');
      final f = File(path);
      final bytes = await f.length();
      print('녹음된 파일 크기: $bytes bytes');
      await Logger().log('녹음된 파일 크기: $bytes bytes');
    }
    await _processRecording();
  }

  Future<String> _convertAndSend(String path) async {
    final outputPath = path.replaceAll(RegExp(r'\.\w+$'), '.wav');
    final command = '-y -i "$path" -ar 16000 -ac 1 "$outputPath"';
    await Logger().log('FFmpeg 변환 시작: $command');
    print('FFmpeg 변환 시작: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      await Logger().log('FFmpeg 변환 성공: $outputPath');
      print('FFmpeg 변환 성공: $outputPath');
      final f = File(outputPath);
      final bytes = await f.length();
      print('변환된 WAV 파일 크기: $bytes bytes');
      await Logger().log('변환된 WAV 파일 크기: $bytes bytes');
      return outputPath;
    } else {
      await Logger().log('FFmpeg 변환 실패: $returnCode');
      print('FFmpeg 변환 실패: $returnCode');
      throw Exception('FFmpeg 변환 실패: $returnCode');
    }
  }

  Future<void> _processRecording() async {
    if (_filePath == null) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = '대화내용 분석중';
    });
    try {
      await Logger().log('녹음 파일 처리 시작: $_filePath');
      print('녹음 파일 처리 시작: $_filePath');
      final processedPath = await _convertAndSend(_filePath!);
      final file = File(processedPath);

      // 디버깅: 업로드할 파일 크기
      final bytes = await file.length();
      print('서버로 전송할 파일: $processedPath, 크기: $bytes bytes');
      await Logger().log('서버로 전송할 파일: $processedPath, 크기: $bytes bytes');

      // 1) STT + Diarize
      print('[API 요청] 화자수: $_selectedSpeakers');
      await Logger().log('[API 요청] 화자수: $_selectedSpeakers');
      final rawJson = await _sttService.transcribeAudioWithSegments(
        file,
        minSpeakers: _selectedSpeakers,
        maxSpeakers: _selectedSpeakers,
      );
      // ... STT 처리 끝나고 요약 요청 직전 메시지 변경!
      setState(() {
        _loadingMessage = '대화내용 요약중';
      });

      if (rawJson == null) {
        print('❌ STT API 응답 없음 (null)');
        throw Exception('음성 인식 실패');
      }
      print('STT+화자분리 API 결과: $rawJson');
      await Logger().log(
          'STT+화자분리 완료, 텍스트: ${rawJson['text']?.substring(0, 20) ?? ""}...');

      final serverDialogues =
          (rawJson['dialogues'] as List).cast<Map<String, dynamic>>();
      setState(() => _dialogues = serverDialogues);

      // 2) 요약 및 환자명 추출
      final summary =
          await _gptService.summarizeText(rawJson['text'] as String);
      if (summary == null || summary is! String || summary.trim().isEmpty) {
        print('❌ GPT 요약이 null, empty 또는 String이 아님: $summary');
        await Logger().log('❌ GPT 요약이 null, empty 또는 String이 아님: $summary');
        throw Exception('요약 실패: GPT 요약이 null 또는 잘못된 값');
      }
      await Logger().log('GPT 요약 완료: $summary');
      final summaryLines =
          summary.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final summaryItems =
          summaryLines.map((l) => SummaryItem(iconCode: '', text: l)).toList();

      final nameRaw =
          await _gptService.extractPatientName(rawJson['text'] as String);
      final patientName =
          (nameRaw?.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_') ?? 'unknown')
              .trim();
      print('환자명 추출: $patientName');

      // ====== 환자명 기반 파일명 생성 및 파일명 변경 ======
      final dir = file.parent.path;
      final nowTs = DateTime.now().millisecondsSinceEpoch;
      final ext = file.path.split('.').last;
      final newAudioPath = '$dir/${patientName}_$nowTs.$ext';
      await file.rename(newAudioPath);
      print('녹음파일 이름 변경: $newAudioPath');
      await Logger().log('녹음파일 이름 변경: $newAudioPath');

      // 3) 메타 저장 및 화면 이동
      // Recording 객체 생성 (audioPath, patientName 모두 반영)
      final rec = Recording(
        audioPath: newAudioPath,
        patientName: patientName,
        originalText: rawJson['text'] as String,
        summaryItems: summaryItems,
        createdAt: DateTime.now(),
        speakers: serverDialogues
            .map((d) => {
                  'speaker': d['speaker'],
                  'start': d['start'],
                  'end': d['end'],
                })
            .toList(),
        labeledTexts: [], // 필요에 따라
        dialogues: serverDialogues,
      );

      await _saveMetaFile(rec); // 메타파일도 자동 환자명 기반으로 저장됨

      await Logger().log('메타 저장 및 화면 이동: ${newAudioPath}');
      print('메타 저장: ${newAudioPath.replaceAll(RegExp(r'\.\w+$'), '.json')}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(initialRecording: rec)),
      );
    } catch (e, st) {
      await Logger().log('오류 발생: $e\n$st');
      print('오류 발생: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
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
        appBar: AppBar(title: const Text('Whisper 녹음')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RecordingControl(
                isRecording: _isRecording,
                isLoading: _isLoading,
                onPressed: _toggleRecording,
                loadingMessage: _loadingMessage,
              ),
              const SizedBox(height: 12),
              RecordingTimer(elapsedMs: _elapsedMs),
              if (_filePath != null) ...[
                const SizedBox(height: 12),
                FileInfoDisplay(filePath: _filePath!),
              ],
              const SizedBox(height: 20),
              const Text("화자 수 설정",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _selectedSpeakers,
                items: [1, 2, 3, 4]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v명')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSpeakers = v);
                },
              ),
              if (_dialogues.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('화자별 대화 내용',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DialoguesList(dialogues: _dialogues),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _saveMetaFile(Recording rec) async {
  final metaPath = rec.audioPath.replaceAll(RegExp(r'\.\w+$'), '.json');
  try {
    await File(metaPath)
        .writeAsString(jsonEncode(rec.toJson()), encoding: utf8);
    print('메타파일 저장됨: $metaPath');
    await Logger().log('메타파일 저장됨: $metaPath');
  } catch (e, st) {
    print('메타파일 저장 오류: $e\n$st');
    await Logger().log('메타파일 저장 오류: $e\n$st');
    // 토스트, 에러 알림 등 사용자 안내
  }
}
