// lib/screens/result_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/permission_gate.dart'; // PermissionGate import
import '../services/pdf_service.dart';
import 'recording_list_screen.dart';
import 'package:permission_handler/permission_handler.dart';

/// 전사된 원문과 선택적 요약문, 오디오 파일 경로, 환자명을 받아 처리하는 화면
class ResultScreen extends StatefulWidget {
  final String originalText;
  final String summaryText;
  final String audioPath;
  final String patientName;

  const ResultScreen({
    Key? key,
    required this.originalText,
    required this.summaryText,
    required this.audioPath,
    required this.patientName,
  }) : super(key: key);

  @override
  ResultScreenState createState() => ResultScreenState();
}

class ResultScreenState extends State<ResultScreen> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _playerSub;
  bool _playerReady = false;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  Duration _totalDuration = Duration.zero;

  PDFService? _pdfService;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _initPdfService();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    _player.setSubscriptionDuration(const Duration(milliseconds: 100));
    _playerSub = _player.onProgress!.listen((e) {
      if (e.duration.inMilliseconds > 0) {
        setState(() {
          _totalDuration = e.duration;
          _playbackProgress =
              e.position.inMilliseconds / e.duration.inMilliseconds;
        });
      }
    });
    setState(() => _playerReady = true);
  }

  Future<void> _initPdfService() async {
    try {
      _pdfService = await PDFService.init();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 기능 초기화 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_playerReady) return;
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() => _isPlaying = false);
    } else {
      await _player.startPlayer(
        fromURI: widget.audioPath,
        codec: Codec.aacMP4,
        whenFinished: () => setState(() => _isPlaying = false),
      );
      setState(() => _isPlaying = true);
    }
  }

  void _seekToPosition(TapDownDetails d) {
    if (!_playerReady || _totalDuration.inMilliseconds == 0) return;
    final box = context.findRenderObject() as RenderBox;
    final dx = d.localPosition.dx.clamp(0.0, box.size.width);
    final pos = Duration(
      milliseconds:
          (_totalDuration.inMilliseconds * (dx / box.size.width)).toInt(),
    );
    _player.seekToPlayer(pos);
  }

  void _dragSeek(DragUpdateDetails d) {
    if (!_playerReady || _totalDuration.inMilliseconds == 0) return;
    final box = context.findRenderObject() as RenderBox;
    final dx = d.localPosition.dx.clamp(0.0, box.size.width);
    final pos = Duration(
      milliseconds:
          (_totalDuration.inMilliseconds * (dx / box.size.width)).toInt(),
    );
    _player.seekToPlayer(pos);
  }

  /// PDF 생성 및 공유 호출
  Future<void> _generatePdf() async {
    if (_isGeneratingPdf || _pdfService == null) return;

    // ── 모든 파일 접근 권한 확인 ──
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        // 허용되어 있지 않으면 설정 화면으로 이동
        final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('모든 파일 접근 권한 필요'),
                content: const Text(
                    'PDF 저장을 위해 “모든 파일 접근” 권한이 필요합니다.\n설정 화면으로 이동하시겠어요?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('설정으로')),
                ],
              ),
            ) ??
            false;

        if (ok) {
          await openAppSettings();
        }
        return; // 권한 없으면 여기서 종료
      }
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final file = await _pdfService!.generatePdf(
        patientName: widget.patientName,
        summaryText: widget.summaryText,
      );
      await _pdfService!.sharePdf(file);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 저장 및 공유 완료:\n${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성 오류: $e')),
      );
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      requireMicrophone: false,
      requireStorage: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('요약 결과')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🔊 대화 내용:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
                child: SingleChildScrollView(child: Text(widget.originalText))),
            const Divider(height: 32),
            const Text('✏️ AI 요약:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
                child: SingleChildScrollView(child: Text(widget.summaryText))),
            const Divider(height: 32),
            const Text('🎧 녹음 재생:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(7.5),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _seekToPosition,
                onHorizontalDragUpdate: _dragSeek,
                child: LinearProgressIndicator(
                  value: _playbackProgress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation(Colors.teal),
                  minHeight: 15,
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow,
                    color: Colors.teal),
                onPressed: _togglePlay,
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: const Text('녹음 목록'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RecordingListScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(_isGeneratingPdf ? '생성 중…' : 'PDF 출력'),
                  onPressed: _isGeneratingPdf ? null : () => _generatePdf(),
                ),
              ),
            ]).animate().fadeIn(delay: 700.ms),
          ]),
        ),
      ),
    );
  }
}
