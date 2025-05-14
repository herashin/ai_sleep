import 'package:flutter/material.dart';

class OriginalTextSection extends StatelessWidget {
  final String text;

  const OriginalTextSection({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔊 대화 내용:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(child: Text(text)),
          ),
        ],
      ),
    );
  }
}
