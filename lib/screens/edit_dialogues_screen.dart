// lib/screens/edit_dialogues_screen.dart

import 'package:flutter/material.dart';

class EditDialoguesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> dialogues;

  const EditDialoguesScreen({
    Key? key,
    required this.dialogues,
  }) : super(key: key);

  @override
  State<EditDialoguesScreen> createState() => _EditDialoguesScreenState();
}

class _EditDialoguesScreenState extends State<EditDialoguesScreen> {
  late List<Map<String, dynamic>> editedDialogues;

  @override
  void initState() {
    super.initState();
    // 딥카피하여 로컬 상태에서만 수정
    editedDialogues =
        widget.dialogues.map((d) => Map<String, dynamic>.from(d)).toList();
  }

  void _onSave() {
    // 저장 시 현재 편집된 리스트 반환
    Navigator.pop(context, editedDialogues);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('화자별 대화 수정'),
        actions: [
          TextButton(
            onPressed: _onSave,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: editedDialogues.length,
        itemBuilder: (_, idx) {
          final d = editedDialogues[idx];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: d['speaker'] ?? '',
                          decoration: const InputDecoration(labelText: '화자'),
                          onChanged: (val) =>
                              editedDialogues[idx]['speaker'] = val,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          initialValue: d['start']?.toString() ?? '',
                          decoration: const InputDecoration(labelText: '시작'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => editedDialogues[idx]['start'] =
                              double.tryParse(val) ?? 0.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          initialValue: d['end']?.toString() ?? '',
                          decoration: const InputDecoration(labelText: '종료'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => editedDialogues[idx]['end'] =
                              double.tryParse(val) ?? 0.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => editedDialogues.removeAt(idx));
                        },
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: d['text'] ?? '',
                    decoration: const InputDecoration(labelText: '대화 내용'),
                    maxLines: null,
                    onChanged: (val) => editedDialogues[idx]['text'] = val,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            editedDialogues.add({
              "speaker": "",
              "text": "",
              "start": 0.0,
              "end": 0.0,
            });
          });
        },
      ),
    );
  }
}
