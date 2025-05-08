// lib/services/stt_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class STTService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY']!;

  Future<String?> transcribeAudio(File audioFile) async {
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..fields['model'] = 'whisper-1'
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));
    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode == 200) {
      return json.decode(resp.body)['text'] as String;
    } else {
      print('STT 오류 ${resp.statusCode}: ${resp.body}');
      return null;
    }
  }
}
