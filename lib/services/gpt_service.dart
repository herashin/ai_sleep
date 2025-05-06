// GPT summarization
// lib/services/gpt_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GPTService {
  /// 환경변수에 저장된 OpenAI API 키
  final String _apiKey = dotenv.env['OPENAI_API_KEY']!;

  /// STT 텍스트를 입력 받아 요약 결과 반환
  Future<String?> summarizeText(String inputText) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };
      final body = json.encode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'user',
            'content': '''
다음은 환자와 의료진의 상담 대화입니다.
---
$inputText
---
이 대화를 참고하여 전자차트 기록용으로 요약해주세요.
다음과 같은 형식으로 응답해 주세요:
📋 진료기록 요약:
- 🦷 치식: [ex. #46]
- 📝 치료계획: [ex. 크라운 치료 예정]
- 💰 예상 비용: [ex. 45만 원]
- 🗓 다음 예약일: [ex. 2025년 4월 26일]

다른 불필요한 설명은 하지 마세요.
'''
          }
        ],
        'temperature': 0.4,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return data['choices'][0]['message']['content'] as String;
      }
      print('GPT API 오류: ${response.statusCode}');
      return null;
    } catch (e) {
      print('GPT 호출 예외: $e');
      return null;
    }
  }
}
