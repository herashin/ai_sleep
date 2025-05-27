// lib/widgets/file_info_display.dart
// 녹음된 음성파일의 저장 경로를 사용자에게 표시해주는 위젯
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
