import 'package:flutter/material.dart';
import '../models/summary_item.dart';
import 'summary_section.dart';

class AISummarySection extends StatelessWidget {
  final List<SummaryItem> items;

  const AISummarySection({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✏️ AI 요약:', style: TextStyle(fontWeight: FontWeight.bold)),
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
