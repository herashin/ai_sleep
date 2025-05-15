import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/speech/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

class GoogleSTTService {
  final _scopes = [SpeechApi.cloudPlatformScope];

  Future<String?> transcribe(File audioFile, String encoding) async {
    try {
      // JSON 키 파일 로드 (Flutter assets 방식)
      final jsonStr = await rootBundle
          .loadString('assets/mineral-battery-459905-i3-27ecd47986ab.json');
      final serviceAccount = ServiceAccountCredentials.fromJson(jsonStr);

      final client = await clientViaServiceAccount(serviceAccount, _scopes);
      final speechApi = SpeechApi(client);

      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      final request = RecognizeRequest.fromJson({
        'config': {
          'encoding': encoding, // 👈 인자로 받은 encoding 사용
          'sampleRateHertz': 16000,
          'languageCode': 'ko-KR',
        },
        'audio': {
          'content': audioBase64,
        },
      });

      final response = await speechApi.speech.recognize(request);
      client.close();

      if (response.results != null && response.results!.isNotEmpty) {
        return response.results!
            .map((e) => e.alternatives!.first.transcript)
            .join('\n');
      } else {
        print('Google STT 결과 없음');
        return null;
      }
    } catch (e) {
      print('❌ Google STT 오류: $e');
      return null;
    }
  }
}
