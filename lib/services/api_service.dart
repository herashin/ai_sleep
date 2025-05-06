// Backend API wrapper
// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class APIService {
  /// 백엔드 서버 베이스 URL
  final String baseUrl = 'https://your-server.com';

  /// 녹음 파일 업로드 후 요약 결과 반환
  Future<String?> uploadAndSummarize(File audioFile) async {
    try {
      final uri = Uri.parse('$baseUrl/transcribe_and_summarize');
      final request = http.MultipartRequest('POST', uri);

      // 파일 추가
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          contentType: MediaType('audio', 'aac'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['summary'] as String?;
      } else {
        print('서버 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('API 호출 예외: $e');
      return null;
    }
  }
}
