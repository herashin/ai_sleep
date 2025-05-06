// Copy & share widget
// lib/widgets/result_share_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';

/// 요약 결과를 복사 및 공유할 수 있는 위젯
class ResultShareWidget extends StatelessWidget {
  final String result;

  const ResultShareWidget({super.key, required this.result});

  /// 클립보드에 텍스트 복사
  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result));
    Fluttertoast.showToast(msg: '클립보드에 복사되었습니다.');
  }

  /// 공유 옵션 호출 (카카오톡 등)
  void _shareText() {
    Share.share(result, subject: '진료 요약 결과 공유');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => _copyToClipboard(context),
          icon: const Icon(Icons.copy),
          label: const Text('복사하기'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _shareText,
          icon: const Icon(Icons.share),
          label: const Text('공유하기'),
        ),
      ],
    );
  }
}
