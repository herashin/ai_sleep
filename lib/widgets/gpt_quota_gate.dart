// lib/widgets/gpt_quota_gate.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 화면 진입 시 한 번만 GPT 크레딧(무료 사용량) 조회 후
/// 통과하면 child를, 부족하면 경고 다이얼로그 후 팝 처리
class GptQuotaGate extends StatefulWidget {
  final Widget child;
  const GptQuotaGate({Key? key, required this.child}) : super(key: key);

  @override
  GptQuotaGateState createState() => GptQuotaGateState();
}

class GptQuotaGateState extends State<GptQuotaGate> {
  bool? _hasQuota;

  @override
  void initState() {
    super.initState();
    _checkQuota();
  }

  Future<void> _checkQuota() async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      final uri =
          Uri.parse('https://api.openai.com/v1/dashboard/credit_grants');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final remaining = (data['total_available_credits'] as num).toDouble();
        if (!mounted) return;

        if (remaining > 0) {
          setState(() => _hasQuota = true);
        } else {
          // 크레딧 부족
          await _showNoQuotaDialog();
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        // 조회 실패 시에도 팝
        await _showNoQuotaDialog();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      // 예외 시 팝 처리
      await _showNoQuotaDialog();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _showNoQuotaDialog() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('크레딧 부족'),
        content: const Text('남은 크레딧이 없습니다.\n충전 후 다시 시도해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_hasQuota == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // 크레딧 OK: 자식 위젯 렌더
    return widget.child;
  }
}
