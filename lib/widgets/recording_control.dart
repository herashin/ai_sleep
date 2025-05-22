// lib/widgets/recording_control.dart
import 'package:flutter/material.dart';

class RecordingControl extends StatelessWidget {
  final bool isRecording;
  final bool isLoading;
  final VoidCallback onPressed;

  const RecordingControl({
    Key? key,
    required this.isRecording,
    required this.isLoading,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isRecording ? Icons.mic : Icons.mic_none,
          size: 80,
          color: isRecording ? Colors.red : Colors.grey,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Text(isRecording ? '녹음 중지' : '녹음 시작'),
        ),
      ],
    );
  }
}
