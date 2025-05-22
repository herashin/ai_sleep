import 'package:flutter/material.dart';

class OriginalTextSection extends StatelessWidget {
  final List<Map<String, dynamic>> dialogues;

  const OriginalTextSection({Key? key, required this.dialogues})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔊 화자별 대화 내용:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: dialogues.length,
              itemBuilder: (_, index) {
                final d = dialogues[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '[${d["speaker"]}] ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 16),
                        ),
                        TextSpan(
                          text: d["text"],
                          style: const TextStyle(
                              color: Colors.black, fontSize: 16),
                        ),
                        // 시간정보도 표시하고 싶다면 아래 주석 해제
                        // TextSpan(
                        //   text: " (${d["start"].toStringAsFixed(2)}~${d["end"].toStringAsFixed(2)}초)",
                        //   style: TextStyle(
                        //       color: Colors.grey[600], fontSize: 13),
                        // ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
