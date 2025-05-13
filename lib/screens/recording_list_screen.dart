// lib/screens/recording_list_screen.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../widgets/recording_list_item.dart';
import '../models/recording.dart';
import 'result_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureManageStoragePermission() async {
  // 먼저 권한 상태를 정확히 확인
  final status = await Permission.manageExternalStorage.status;
  if (status.isGranted) {
    debugPrint('✅ 모든 파일 접근 권한이 이미 허용되어 있습니다.');
    return true;
  } else {
    debugPrint('🚩 모든 파일 접근 권한을 요청합니다.');
    final result = await Permission.manageExternalStorage.request();
    debugPrint('✅ 권한 요청 결과: $result');
    return result.isGranted;
  }
}

// 이 함수는 꼭 클래스 외부에 최상위로 선언해야 합니다.
Future<List<Recording>> fetchRecordingsFromDir(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return [];

  final recs = <Recording>[];
  await for (final entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      try {
        final jsonString = await entity.readAsString(encoding: utf8);
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        recs.add(Recording.fromJson(map));
      } catch (_) {
        // 오류난 파일은 무시하고 계속 진행
      }
    }
  }

  recs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return recs;
}

class RecordingListScreen extends StatefulWidget {
  const RecordingListScreen({Key? key}) : super(key: key);

  @override
  RecordingListScreenState createState() => RecordingListScreenState();
}

class RecordingListScreenState extends State<RecordingListScreen> {
  bool _loading = true;
  List<Recording> _recs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    ensureManageStoragePermission();
    debugPrint('▶▶▶ RecordingListScreen.initState()');
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    debugPrint('🚩 _fetchRecordings() 호출됨');
    try {
      final recs =
          await compute(fetchRecordingsFromDir, '/storage/emulated/0/AI_Sleep');
      debugPrint('✅ compute 완료, recordings 개수: ${recs.length}');

      if (!mounted) return;
      setState(() {
        _recs = recs;
        _loading = false;
      });

      for (final r in recs) {
        debugPrint(
            '📌 로드된 recording: ${r.patientName}, ${r.audioPath}, ${r.createdAt}, summaryItems 개수: ${r.summaryItems.length}');
      }
    } catch (e, stack) {
      debugPrint('🚨 fetchRecordings 예외 발생: $e, stack: $stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '▶▶▶ RecordingListScreen.build() [loading=$_loading, error=$_error, count=${_recs.length}]');
    return Scaffold(
      appBar: AppBar(title: const Text('녹음 기록 목록')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('에러 발생: $_error'))
              : _recs.isEmpty
                  ? const Center(child: Text('저장된 녹음이 없습니다.'))
                  : ListView.builder(
                      itemCount: _recs.length,
                      itemBuilder: (ctx, i) {
                        debugPrint('🚩 itemBuilder 호출됨: index=$i');
                        final rec = _recs[i];
                        return RecordingListItem(
                          rec: rec,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultScreen(recording: rec),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
