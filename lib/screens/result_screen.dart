// lib/screens/result_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../models/summary_item.dart';
import '../widgets/original_text_section.dart';
import '../widgets/ai_summary_section.dart';
import '../widgets/audio_player_section.dart';
import '../widgets/pdf_export_buttons.dart';
import '../widgets/permission_gate.dart';
import 'edit_original_text_screen.dart';
import 'edit_dialogues_screen.dart';
import '../services/gpt_service.dart';

class ResultScreen extends StatefulWidget {
  final Recording initialRecording;

  const ResultScreen({Key? key, required this.initialRecording})
      : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Recording rec;
  final GPTService _gptService = GPTService();

  bool _isSummaryLoading = false;

  @override
  void initState() {
    super.initState();
    rec = widget.initialRecording;
  }

  /// originalText만 업데이트 후 JSON 메타파일에도 덮어쓰고,
  /// 저장 후 실제 파일에서 재로딩하여 최신 데이터로 화면 갱신!
  Future<void> _saveOriginalText(String updated) async {
    final metaPath = rec.audioPath.replaceAll(RegExp(r'\.\w+$'), '.json');
    final file = File(metaPath);

    final Map<String, dynamic> jsonMap = rec.toJson()
      ..['originalText'] = updated;

    await file.writeAsString(json.encode(jsonMap));

    final reloadedJson = json.decode(await file.readAsString());
    setState(() {
      rec = Recording.fromJson(reloadedJson);
    });
  }

  Future<void> _saveDialogues(
      List<Map<String, dynamic>> updatedDialogues) async {
    final metaPath = rec.audioPath.replaceAll(RegExp(r'\.\w+$'), '.json');
    final file = File(metaPath);

    final mergedText = updatedDialogues
        .map((d) => (d['text'] ?? '').toString().trim())
        .where((t) => t.isNotEmpty)
        .join('\n');

    final Map<String, dynamic> jsonMap = rec.toJson()
      ..['dialogues'] = updatedDialogues
      ..['originalText'] = mergedText;

    await file.writeAsString(json.encode(jsonMap));

    final reloadedJson = json.decode(await file.readAsString());
    setState(() {
      rec = Recording.fromJson(reloadedJson);
    });
  }

  // ====== AI 요약 갱신 함수 추가 ======
  Future<void> _refreshAISummary() async {
    setState(() => _isSummaryLoading = true);

    try {
      // 최신 대화 텍스트로 요약 요청 (필요시 rec.dialogues 합치기 가능)
      final inputText = rec.originalText;

      final result = await _gptService.reviseAndSummarize(inputText);

      // 요약(네줄) -> SummaryItem 리스트 변환
      final newSummaryItems = result.summary
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
        final emojiMatch = RegExp(r'\[(.*?)\]').firstMatch(line);
        final emojiCode = emojiMatch?.group(1) ?? '';
        // 👇 text에 [이모지코드]까지 넣어서 저장!
        final pureText = line.replaceAll(RegExp(r'\[.*?\]\s*'), '');
        return SummaryItem(
          iconCode: emojiCode,
          text: '[${emojiCode}] $pureText', // 이 부분!
        );
      }).toList();

      // 메타파일 summaryItems 갱신
      final metaPath = rec.audioPath.replaceAll(RegExp(r'\.\w+$'), '.json');
      final file = File(metaPath);
      final Map<String, dynamic> jsonMap = rec.toJson()
        ..['summaryItems'] = newSummaryItems.map((e) => e.toJson()).toList();
      await file.writeAsString(json.encode(jsonMap));

      // 파일을 다시 읽어서 최신 상태 반영
      final reloadedJson = json.decode(await file.readAsString());
      setState(() {
        rec = Recording.fromJson(reloadedJson);
      });
    } catch (e, stack) {
      debugPrint('AI 요약 갱신 실패: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 요약 갱신에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSummaryLoading = false);
    }
  }
  // =================================

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
                final updatedDialogues =
                    await Navigator.push<List<Map<String, dynamic>>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDialoguesScreen(
                      dialogues: rec.dialogues,
                    ),
                  ),
                );
                if (updatedDialogues != null) {
                  await _saveDialogues(updatedDialogues);
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
              // 원본 대화: 화자별 대화 리스트로 출력
              OriginalTextSection(dialogues: rec.dialogues),
              const Divider(height: 32),
              // AI 요약 결과
              AISummarySection(
                items: rec.summaryItems,
                onRefresh: _isSummaryLoading ? null : _refreshAISummary,
                isLoading: _isSummaryLoading,
              ),
              const Divider(height: 32),
              // 오디오 플레이어
              AudioPlayerSection(audioPath: rec.audioPath),
              const SizedBox(height: 20),
              // PDF/목록 내비게이션 버튼
              PDFExportButtons(recording: rec),
            ],
          ),
        ),
      ),
    );
  }
}
