// lib/widgets/recording_control.dart
import 'package:flutter/material.dart';

class RecordingControl extends StatelessWidget {
  final bool isRecording;
  final bool isLoading;
  final VoidCallback onPressed;
  final String? loadingMessage; // 추가!

  const RecordingControl({
    Key? key,
    required this.isRecording,
    required this.isLoading,
    required this.onPressed,
    this.loadingMessage, // 추가!
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
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(150, 48),
          ),
          child: isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    ),
                    const SizedBox(width: 12),
                    Text(loadingMessage ?? '처리중...',
                        style: const TextStyle(fontSize: 16)),
                  ],
                )
              : Text(isRecording ? '녹음 중지' : '녹음 시작'),
        ),
      ],
    );
  }
}
