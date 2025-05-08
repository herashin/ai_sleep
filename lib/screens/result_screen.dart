// lib/screens/result_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'recording_list_screen.dart';

/// 전사된 원문과 선택적 요약문, 오디오 파일 경로를 보여주는 화면
class ResultScreen extends StatefulWidget {
  /// STT로 전사된 원문 텍스트
  final String originalText;

  /// GPT 요약 텍스트 (nullable)
  final String? summaryText;

  /// 저장된 오디오 파일 경로 (nullable)
  final String? audioPath;

  const ResultScreen({
    Key? key,
    required this.originalText,
    this.summaryText,
    this.audioPath,
  }) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _playerSub;
  bool _playerReady = false;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    _player.setSubscriptionDuration(const Duration(milliseconds: 100));
    _playerSub = _player.onProgress!.listen((event) {
      if (event.duration.inMilliseconds > 0) {
        setState(() {
          _totalDuration = event.duration;
          _playbackProgress =
              event.position.inMilliseconds / event.duration.inMilliseconds;
        });
      }
    });
    setState(() => _playerReady = true);
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_playerReady || widget.audioPath == null) return;
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() => _isPlaying = false);
    } else {
      await _player.startPlayer(
        fromURI: widget.audioPath!,
        codec: Codec.aacMP4,
        whenFinished: () {
          setState(() => _isPlaying = false);
        },
      );
      setState(() => _isPlaying = true);
    }
  }

  void _seekToPosition(TapDownDetails details) {
    if (!_playerReady || _totalDuration.inMilliseconds == 0) return;
    final box = context.findRenderObject() as RenderBox;
    final tapX = details.localPosition.dx.clamp(0.0, box.size.width);
    final ratio = tapX / box.size.width;
    final newPos = Duration(
      milliseconds: (_totalDuration.inMilliseconds * ratio).toInt(),
    );
    _player.seekToPlayer(newPos);
  }

  void _dragSeek(DragUpdateDetails details) {
    if (!_playerReady || _totalDuration.inMilliseconds == 0) return;
    final box = context.findRenderObject() as RenderBox;
    final dragX = details.localPosition.dx.clamp(0.0, box.size.width);
    final ratio = dragX / box.size.width;
    final newPos = Duration(
      milliseconds: (_totalDuration.inMilliseconds * ratio).toInt(),
    );
    _player.seekToPlayer(newPos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('요약 결과')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔊  대화 내용:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(widget.originalText),
              ),
            ),
            if (widget.summaryText != null) ...[
              const Divider(height: 32),
              const Text('✏️ AI 요약:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(widget.summaryText!),
                ),
              ),
              const Divider(height: 32),
              const Text('🎧 녹음 재생:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // 진행바에 터치/드래그 탐색과 둥근 모서리 적용
              ClipRRect(
                borderRadius: BorderRadius.circular(7.5),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _seekToPosition,
                  onHorizontalDragUpdate: _dragSeek,
                  child: LinearProgressIndicator(
                    value: _playbackProgress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.teal),
                    minHeight: 15,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.stop : Icons.play_arrow,
                      color: Colors.teal,
                    ),
                    onPressed: _togglePlay,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('녹음 목록 바로가기'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecordingListScreen(),
                  ),
                );
              },
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
