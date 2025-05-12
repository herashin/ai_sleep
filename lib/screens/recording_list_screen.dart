// lib/screens/recording_list_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/permission_gate.dart';
import '../models/recording.dart';
import '../widgets/summary_section.dart';
import 'result_screen.dart';

class RecordingListScreen extends StatefulWidget {
  const RecordingListScreen({Key? key}) : super(key: key);

  @override
  _RecordingListScreenState createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen> {
  bool _loading = true;
  List<Recording> _recs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    debugPrint('▶ _fetchRecordings start');
    try {
      final dir = Directory('/storage/emulated/0/AI_Sleep');
      if (!await dir.exists()) {
        setState(() {
          _recs = [];
          _loading = false;
        });
        return;
      }

      final recs = <Recording>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final jsonString = await entity.readAsString(encoding: utf8);
            final map = jsonDecode(jsonString) as Map<String, dynamic>;
            recs.add(Recording.fromJson(map));
          } catch (e) {
            debugPrint('메타 파싱 실패: ${entity.path} → $e');
          }
        }
      }
      recs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _recs = recs;
        _loading = false;
      });
      debugPrint('◀ _fetchRecordings end: total=${recs.length}');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      requireMicrophone: false,
      requireStorage: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('녹음 기록 목록')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Text('에러 발생: $_error')
                  : _recs.isEmpty
                      ? const Text('저장된 녹음이 없습니다.')
                      : ListView.builder(
                          itemCount: _recs.length,
                          itemBuilder: (ctx, i) {
                            final rec = _recs[i];
                            debugPrint('▶ build item $i (${rec.patientName})');
                            final timeLabel = DateFormat('yyyy.MM.dd HH:mm')
                                .format(rec.createdAt);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ResultScreen(recording: rec),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.audiotrack,
                                                color: Colors.teal,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${rec.patientName} 환자 진료상담 요약',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Icon(Icons.chevron_right),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeLabel,
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      // 실제 요약 미리보기
                                      // SummarySection(
                                      //   items: rec.summaryItems.length > 3
                                      //       ? rec.summaryItems.sublist(0, 3)
                                      //       : rec.summaryItems,
                                      //   iconSize: 16,
                                      //   textStyle:
                                      //       const TextStyle(fontSize: 12),
                                      // ),
                                      // SVG 로딩 빼고 단순 텍스트만 표시
                                      Text(
                                        rec.summaryItems
                                            .map((e) => e.text)
                                            .join('\n'),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
