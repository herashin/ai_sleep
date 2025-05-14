import 'package:flutter/material.dart';
import '../models/recording.dart';

class PDFExportButtons extends StatelessWidget {
  final Recording recording;

  const PDFExportButtons({Key? key, required this.recording}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('녹음 목록'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF 출력'),
          onPressed: () {
            // PDF 생성 로직은 이곳에 삽입하거나 콜백함수로 전달 가능
          },
        ),
      ),
    ]);
  }
}
