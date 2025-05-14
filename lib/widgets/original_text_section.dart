// lib/widgets/original_text_section.dart

import 'package:flutter/material.dart';

/// 화면에 대화 원문을 보여주는 단순 출력 위젯
class OriginalTextSection extends StatelessWidget {
  final String text;

  const OriginalTextSection({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔊 대화 내용:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
