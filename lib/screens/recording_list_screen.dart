// lib/screens/recording_list_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recording.dart';
import 'result_screen.dart';

class RecordingListScreen extends StatelessWidget {
  const RecordingListScreen({super.key});

  Future<List<Recording>> _loadRecordings() async {
    final dir = Directory('/storage/emulated/0/AI_Sleep');
    if (!await dir.exists()) return [];

    final files = await dir.list().toList();
    final recs = <Recording>[];

    for (var f in files) {
      if (f is File && f.path.endsWith('.m4a')) {
        final metaPath = f.path.replaceAll('.m4a', '.json');
        if (await File(metaPath).exists()) {
          final meta = jsonDecode(await File(metaPath).readAsString())
              as Map<String, dynamic>;
          recs.add(Recording(
            audioPath: f.path,
            originalText: meta['originalText'] as String,
            summaryText: meta['summaryText'] as String,
            createdAt: DateTime.parse(meta['createdAt'] as String),
            patientName: meta['patientName'] as String? ?? '알 수 없음',
          ));
        }
      }
    }

    // 최신순 정렬
    recs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('녹음 기록 목록')),
      body: FutureBuilder<List<Recording>>(
        future: _loadRecordings(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final recordings = snap.data ?? [];
          if (recordings.isEmpty) {
            return const Center(child: Text('저장된 녹음이 없습니다.'));
          }
          return ListView.builder(
            itemCount: recordings.length,
            itemBuilder: (ctx, i) {
              final rec = recordings[i];
              final timeLabel =
                  DateFormat('yyyy.MM.dd HH:mm').format(rec.createdAt);
              final title = '${rec.patientName} 환자 진료상담 요약';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.audiotrack, color: Colors.teal),
                  title:
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(timeLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        originalText: rec.originalText,
                        summaryText: rec.summaryText,
                        audioPath: rec.audioPath,
                        patientName: rec.patientName, // 환자명 전달
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
