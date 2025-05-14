import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GPTService {
  final String _apiKey;

  GPTService() : _apiKey = _loadApiKey();

  /// dotenv에서 API 키를 읽고 유효성 검증
  static String _loadApiKey() {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('OPENAI_API_KEY가 설정되지 않았습니다.');
    }
    return key;
  }

  /// 공통 Chat Completion 호출 메서드
  Future<Map<String, dynamic>?> _chatCompletion({
    required List<Map<String, String>> messages,
    double temperature = 0.0,
  }) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
    final body = json.encode({
      'model': 'gpt-4',
      'messages': messages,
      'temperature': temperature,
    });

    try {
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('GPT API 오류 (${response.statusCode}): ${response.body}');
        return null;
      }

      return json.decode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on Exception catch (e, stack) {
      print('GPT 호출 예외: $e\n$stack');
      return null;
    }
  }

  /// 전자차트용 네 줄 요약 + 이모지 코드 태그
  Future<String?> summarizeText(String inputText) async {
    final prompt = '''다음은 환자와 의료진의 상담 대화입니다.
---
$inputText
---
위 대화를 참고하여 전자차트 기록용 네 줄 요약을 생성해 주세요.
각 줄은 반드시 아래 형식을 준수해야 합니다:

[이모지 코드] 텍스트

예시:
[1f9b7] 치식: #36, 어금니 충치 발견
[1f4cb] 치료계획: 신경치료 및 크라운
[1f4b0] 예상 비용: 약 50만 원
[1f5d3] 다음 예약일: 2025년 5월 20일

- 줄바꿈(\n)만 사용하세요.
- 다른 설명은 추가하지 마세요.
''';

    final data = await _chatCompletion(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.4,
    );
    if (data == null) return null;

    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    return content?.trim();
  }

  /// 대화에서 환자 이름만 단일 줄 출력
  Future<String?> extractPatientName(String inputText) async {
    final prompt = '''다음은 환자와 의료진의 상담 대화입니다.
---
$inputText
---
환자의 이름만 오직 한 줄로 출력해 주세요.
예시) 홍길동
다른 설명은 포함하지 마세요.
''';

    final data = await _chatCompletion(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.0,
    );
    if (data == null) return null;

    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    return content?.trim();
  }

  /// STT된 대화 다듬기 및 태그된 네 줄 요약 반환
  Future<({String cleanedText, String summary, List<String> summaryIcons})>
      reviseAndSummarize(String inputText) async {
    final prompt = '''다음은 STT(음성 인식)된 상담 대화입니다.
1) “[수정된 대화문 시작]”과 “[수정된 대화문 끝]” 사이에 자연스럽게 다듬은 대화문을 작성하세요.
2) “[요약 시작]”과 “[요약 끝]” 사이에 네 줄 요약을 작성하되, 각 줄 앞에 [이모지 코드]를 포함하세요.

[수정된 대화문 시작]
(여기에 다듬은 대화문)
[수정된 대화문 끝]

[요약 시작]
[1f9b7] 치식: …
[1f4cb] 치료계획: …
[1f4b0] 예상 비용: …
[1f5d3] 다음 예약일: …
[요약 끝]

STT 원문:
---
$inputText
''';

    final data = await _chatCompletion(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.3,
    );
    if (data == null) {
      return (
        cleanedText: inputText,
        summary: '',
        summaryIcons: <String>[],
      );
    }

    final content = (data['choices'] as List<dynamic>)[0]['message']?['content']
            as String? ??
        '';

    // 다듬은 대화 파싱
    final cleanedMatch =
        RegExp(r'\[수정된 대화문 시작\]([\s\S]*?)\[수정된 대화문 끝\]').firstMatch(content);
    final cleaned = cleanedMatch?.group(1)?.trim() ?? inputText;

    // 요약 부분 파싱
    final summaryBlock = RegExp(r'\[요약 시작\]([\s\S]*?)\[요약 끝\]')
        .firstMatch(content)
        ?.group(1)
        ?.trim();

    final summaryLines = summaryBlock
            ?.split('\n')
            .where((l) => l.trim().startsWith('['))
            .take(4)
            .map((l) => l.trim())
            .toList() ??
        <String>[];

    final icons = summaryLines
        .map((l) => RegExp(r'\[(.*?)\]').firstMatch(l)?.group(1) ?? '')
        .toList();

    return (
      cleanedText: cleaned,
      summary: summaryLines.join('\n'),
      summaryIcons: icons,
    );
  }
}
