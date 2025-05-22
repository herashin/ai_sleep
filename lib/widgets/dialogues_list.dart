// lib/widgets/dialogues_list.dart
import 'package:flutter/material.dart';

class DialoguesList extends StatelessWidget {
  final List<Map<String, dynamic>> dialogues;

  const DialoguesList({Key? key, required this.dialogues}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: dialogues.length,
        itemBuilder: (context, index) {
          final d = dialogues[index];
          return ListTile(
            title: Text('[${d['speaker']}] ${d['text']}'),
            subtitle: Text(
                '(${(d['start'] as double).toStringAsFixed(2)}~${(d['end'] as double).toStringAsFixed(2)}초)'),
          );
        },
      ),
    );
  }
}
