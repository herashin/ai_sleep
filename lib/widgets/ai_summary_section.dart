import 'package:flutter/material.dart';
import '../models/summary_item.dart';
import 'summary_section.dart';

class AISummarySection extends StatelessWidget {
  final List<SummaryItem> items;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const AISummarySection({
    Key? key,
    required this.items,
    required this.onRefresh,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '✏️ AI 요약:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: isLoading ? null : onRefresh,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLoading ? '갱신중...' : 'AI 요약 갱신',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (isLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                      ),
                    ),
                  ],
                ],
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
