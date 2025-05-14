import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'dart:io';

class AudioPlayerSection extends StatefulWidget {
  final String audioPath;

  const AudioPlayerSection({Key? key, required this.audioPath})
      : super(key: key);

  @override
  _AudioPlayerSectionState createState() => _AudioPlayerSectionState();
}

class _AudioPlayerSectionState extends State<AudioPlayerSection> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _playerSub;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    _player.setSubscriptionDuration(const Duration(milliseconds: 100));
    _playerSub = _player.onProgress!.listen((e) {
      if (e.duration.inMilliseconds > 0) {
        setState(() {
          _playbackProgress =
              e.position.inMilliseconds / e.duration.inMilliseconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  void _togglePlay() async {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🎧 녹음 재생:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(7.5),
          child: LinearProgressIndicator(
            value: _playbackProgress,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation(Colors.teal),
            minHeight: 15,
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.teal),
            onPressed: _togglePlay,
          ),
        ]),
      ],
    );
  }
}
