import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GPTService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY']!;

  /// 상담 대화를 전자차트용 네 줄 요약 (이모지 없이, 줄바꿈만 사용)
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
위 대화를 참고하여 전자차트 기록용으로 네 줄(줄바꿈만 사용) 요약을 해주세요.
다음과 같은 형식으로, 반드시 줄바꿈(\\n)만으로 구분된 네 줄로 응답해 주세요:
진료기록 요약:
치식: [예시 #46]
치료계획: [예시 크라운 치료 예정]
예상 비용: [예시 45만 원]
다음 예약일: [예시 2025년 4월 26일]

다른 설명은 하지 마세요.
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

  /// 대화에서 환자 이름만 단일 줄로 추출
  Future<String?> extractPatientName(String inputText) async {
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
이 대화에서 환자의 이름만 오직 한 줄로 출력해주세요.
다른 설명은 전혀 하지 말고, 예: 홍길동
'''
          }
        ],
        'temperature': 0.0,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return (data['choices'][0]['message']['content'] as String).trim();
      }
      print('PatientName API 오류: ${response.statusCode}');
      return null;
    } catch (e) {
      print('PatientName 호출 예외: $e');
      return null;
    }
  }

  /// STT 결과를 다듬고, 이모지 없이 네 줄 요약 반환
  Future<({String cleanedText, String summary, List<String> summaryIcons})>
      reviseAndSummarize(String inputText) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

      final prompt = '''
다음은 STT(음성 인식)된 상담 대화입니다.
문맥이 어색하거나 부정확한 부분이 있다면 자연스럽게 수정해주세요.
그 후, 이모지 없이 네 줄(줄바꿈만 사용)로 요약해주세요.

<수정된 대화문>
[문맥에 맞게 다듬은 전체 대화를 여기에 작성해주세요]

<요약>
치식: [예시 #47 충치, 어금니 통증 등]
치료계획: [예시 신경치료 및 임플란트]
예상 비용: [예시 약 120만 원]
다음 예약일: [예시 2025년 5월 13일]

다른 설명은 절대 하지 마세요.
---
$inputText
''';

      final body = json.encode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;

        final cleanedMatch = RegExp(
          r'<수정된 대화문>\s*(.*?)\s*<요약>',
          dotAll: true,
        ).firstMatch(content);
        final summaryMatch = RegExp(
          r'<요약>\s*([\s\S]*)',
          dotAll: true,
        ).firstMatch(content);

        final cleaned = cleanedMatch?.group(1)?.trim() ?? inputText;
        final summary = summaryMatch?.group(1)?.trim() ?? '';

        return (
          cleanedText: cleaned,
          summary: summary,
          summaryIcons: <String>[], // 이모지 사용 안 함
        );
      }

      print('GPT revise API 오류: ${response.statusCode}');
      return (
        cleanedText: inputText,
        summary: '',
        summaryIcons: <String>[],
      );
    } catch (e) {
      print('GPT revise 예외: $e');
      return (
        cleanedText: inputText,
        summary: '',
        summaryIcons: <String>[],
      );
    }
  }
}
