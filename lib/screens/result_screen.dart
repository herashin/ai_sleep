import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final String originalText;
  final String summaryText;

  const ResultScreen({
    Key? key,
    required this.originalText,
    required this.summaryText,
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
            Expanded(child: SingleChildScrollView(child: Text(originalText))),
            const Divider(height: 32),
            const Text('✏️ 요약문:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: SingleChildScrollView(child: Text(summaryText))),
          ],
        ),
      ),
    );
  }
}
