// lib/widgets/recording_timer.dart
import 'package:flutter/material.dart';

class RecordingTimer extends StatelessWidget {
  final int elapsedMs;

  const RecordingTimer({Key? key, required this.elapsedMs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text('녹음 시간: ${(elapsedMs / 1000).toStringAsFixed(1)}초');
  }
}
