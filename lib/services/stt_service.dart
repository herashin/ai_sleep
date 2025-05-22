import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class STTService {
  final String baseUrl;

  STTService({this.baseUrl = 'http://192.168.0.91:5000'});

  /// Flask 서버 /diarize_and_transcribe 호출
  Future<Map<String, dynamic>?> transcribeAudioWithSegments(
      File audioFile) async {
    final uri = Uri.parse('$baseUrl/diarize_and_transcribe');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('file', audioFile.path));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResp = json.decode(response.body);
        return jsonResp;
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
