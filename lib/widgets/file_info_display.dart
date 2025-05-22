// lib/widgets/file_info_display.dart
import 'package:flutter/material.dart';

class FileInfoDisplay extends StatelessWidget {
  final String filePath;

  const FileInfoDisplay({Key? key, required this.filePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      '파일 저장: $filePath',
      textAlign: TextAlign.center,
    );
  }
}
