// lib/screens/result_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../widgets/original_text_section.dart';
import '../widgets/ai_summary_section.dart';
import '../widgets/audio_player_section.dart';
import '../widgets/pdf_export_buttons.dart';
import '../widgets/permission_gate.dart';
import 'edit_original_text_screen.dart';

class ResultScreen extends StatefulWidget {
  final Recording initialRecording;

  const ResultScreen({Key? key, required this.initialRecording})
      : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Recording rec;

  @override
  void initState() {
    super.initState();
    // StatefulWidget 내부에서 변경 가능한 복제본으로 보관
    rec = widget.initialRecording;
  }

  /// originalText만 업데이트 후 JSON 메타파일에 덮어쓰기
  Future<void> _saveOriginalText(String updated) async {
    // 1) 로컬 state 갱신
    setState(() {
      rec = rec.copyWith(originalText: updated);
    });

    // 2) JSON 파일에 덮어쓰기
    final metaPath = rec.audioPath.replaceAll('.wav', '.json');
    final file = File(metaPath);

    // toJson() 기존 구조 유지 + originalText 갱신
    final Map<String, dynamic> jsonMap = rec.toJson()
      ..['originalText'] = updated;

    await file.writeAsString(json.encode(jsonMap));
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      requireMicrophone: false,
      requireStorage: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('요약 결과'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '대화 내용 수정',
              onPressed: () async {
                // 수정 화면으로 이동 → 수정된 텍스트가 돌아오면 저장
                final updated = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditOriginalTextScreen(
                      originalText: rec.originalText,
                    ),
                  ),
                );
                if (updated != null && updated.trim() != rec.originalText) {
                  await _saveOriginalText(updated.trim());
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 원본 대화
              //    OriginalTextSection(text: rec.originalText),
              OriginalTextSection(dialogues: rec.dialogues),
              const Divider(height: 32),
              // AI 요약
              AISummarySection(
                items: rec.summaryItems,
                onRefresh: () {
                  // 요약 갱신 로직 연결 예정
                },
              ),
              const Divider(height: 32),
              // 오디오 플레이어
              AudioPlayerSection(audioPath: rec.audioPath),
              const SizedBox(height: 20),
              // PDF / 목록 내비게이션 버튼
              PDFExportButtons(recording: rec),
            ],
          ),
        ),
      ),
    );
  }
}
