// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
//import 'record_screen.dart';
import 'wisper_record_screen.dart';
import 'recording_list_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../screens/permission_helper.dart'
    as perm_helper; // PermissionHelper import 추가

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final perm_helper.PermissionHelper _permissionHelper =
      perm_helper.PermissionHelper();

  Future<void> _handleStartRecording() async {
    final granted = await _permissionHelper.checkAndRequestPermissions(
      requireMicrophone: true,
      requireStorage: true,
    );
    if (granted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WhisperRecordScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('권한 허용이 필요합니다. 설정에서 권한을 허용해주세요.'),
        ),
      );
    }
  }

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
              color: Color(int.parse(dotenv.env['SIMBOL_COLOR']!)),
            ).animate().fadeIn(duration: 600.ms).scale(),
            const SizedBox(height: 20),
            const Text(
              '의료 상담 녹음부터 요약까지\nAI Sleep',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('진료 녹음 시작하기'),
              onPressed: _handleStartRecording,
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 20),
            // 녹음목록 250508
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
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
