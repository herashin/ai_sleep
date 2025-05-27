import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class STTService {
  /// Wi-Fi 테스트용 고정 URL
  final String baseUrl;

  STTService({this.baseUrl = 'http://192.168.0.91:5000'});

  /// Flask 서버 /diarize_and_transcribe 호출
  Future<Map<String, dynamic>?> transcribeAudioWithSegments(
    File audioFile, {
    int? minSpeakers,
    int? maxSpeakers,
  }) async {
    final uri = Uri.parse('$baseUrl/diarize_and_transcribe');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      // 👇 파라미터를 서버로 전송 (이 부분이 꼭 필요!)
      if (minSpeakers != null) {
        request.fields['min_speakers'] = minSpeakers.toString();
      }
      if (maxSpeakers != null) {
        request.fields['max_speakers'] = maxSpeakers.toString();
      }

      // 필요시 timeout도 걸어 줄 수 있습니다.
      final streamedResponse =
          await request.send().timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('STT 서버 오류: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('STT 서버 요청 실패: $e');
      return null;
    }
  }
}
