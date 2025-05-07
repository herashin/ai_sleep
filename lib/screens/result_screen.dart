// lib/screens/result_screen.dart

import 'package:flutter/material.dart';

/// 전사된 원문과 선택적 요약문을 보여주는 화면
class ResultScreen extends StatelessWidget {
  /// STT로 전사된 원문 텍스트
  final String originalText;

  /// GPT 요약 텍스트 (nullable)
  final String? summaryText;

  const ResultScreen({
    Key? key,
    required this.originalText,
    this.summaryText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('요약 결과')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔊 전사된 텍스트:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(originalText),
              ),
            ),
// summaryText가 있을 때만 요약 섹션 표시
            if (summaryText != null) ...[
              const Divider(height: 32),
              const Text('✏️ 요약문:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(summaryText!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
