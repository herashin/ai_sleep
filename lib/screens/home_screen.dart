// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'record_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SleepVoice AI'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_rounded,
              size: 80,
              color: Colors.teal,
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(),
            const SizedBox(height: 20),
            const Text(
              '의료 상담 녹음부터 요약까지',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('진료 녹음 시작하기'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecordScreen(),
                  ),
                );
              },
            )
                .animate()
                .fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
