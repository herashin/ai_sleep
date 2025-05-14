// lib/screens/edit_original_text_screen.dart

import 'package:flutter/material.dart';

class EditOriginalTextScreen extends StatefulWidget {
  final String originalText;

  const EditOriginalTextScreen({
    Key? key,
    required this.originalText,
  }) : super(key: key);

  @override
  _EditOriginalTextScreenState createState() => _EditOriginalTextScreenState();
}

class _EditOriginalTextScreenState extends State<EditOriginalTextScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.originalText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화 내용 수정'),
        actions: [
          TextButton(
            onPressed: _onSave,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('저장'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '대화 내용을 수정하세요',
          ),
        ),
      ),
    );
  }
}
