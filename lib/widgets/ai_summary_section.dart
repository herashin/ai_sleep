import 'package:flutter/material.dart';
import '../models/summary_item.dart';
import 'summary_section.dart';

class AISummarySection extends StatelessWidget {
  final List<SummaryItem> items;
  final VoidCallback onRefresh;

  const AISummarySection({
    Key? key,
    required this.items,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) Row 로 감싸서 텍스트와 버튼을 같은 줄에 배치
        Row(
          children: [
            const Text(
              '✏️ AI 요약:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(), // 텍스트와 버튼 사이 빈 공간
            TextButton(
              onPressed: onRefresh,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text(
                'AI 요약 갱신',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SummarySection(
          items: items,
          iconSize: 24,
          textStyle: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
