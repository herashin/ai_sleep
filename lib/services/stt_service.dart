// // Whisper API call
// // lib/services/stt_service.dart

// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:http/http.dart' as http;

// class STTService {
//   /// OpenAI Whisper API 키
//   final String _apiKey = dotenv.env['OPENAI_API_KEY']!;

//   /// 녹음된 오디오 파일을 Whisper API로 전송하여 텍스트 변환 결과 반환
//   Future<String?> transcribeAudio(File audioFile) async {
//     try {
//       final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
//       final request = http.MultipartRequest('POST', uri)
//         ..headers['Authorization'] = 'Bearer $_apiKey'
//         ..fields['model'] = 'whisper-1'
//         ..files.add(
//           await http.MultipartFile.fromPath('file', audioFile.path),
//         );

//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body) as Map<String, dynamic>;
//         return data['text'] as String?;
//       } else {
//         print('STT API 오류: ${response.statusCode}');
//         print('응답 내용: ${response.body}');
//         return null;
//       }
//     } catch (e) {
//       print('STT 호출 예외: \$e');
//       return null;
//     }
//   }
// }

// lib/services/stt_service.dart

import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 네이티브 음성인식을 래핑한 STT 서비스
class STTService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  /// 초기화: 권한 요청 및 엔진 초기화
  Future<bool> init() async {
    // 1) 마이크 퍼미션 요청
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print('🔒 마이크 권한 거부됨');
      return false;
    }
    // 2) STT 엔진 초기화
    _initialized = await _speech.initialize(
      onStatus: (s) => print('STT status: $s'),
      onError: (e) => print('STT error: $e'),
    );
    return _initialized;
  }

  /// 한 번의 녹음 세션으로부터 텍스트를 받아옴
  /// _startListening -> 사용자가 종료하면 자동으로 resolve
  Future<String?> transcribe() async {
    if (!_initialized && !await init()) return null;

    // 결과를 completer 로 기다림
    final completer = Completer<String>();

    _speech.listen(
      onResult: (result) {
        // 최종 결과가 떴을 때만 반환
        if (result.finalResult) {
          completer.complete(result.recognizedWords);
        }
      },
      localeId: 'ko_KR', // 필요에 따라 바꾸세요
      listenMode: ListenMode.confirmation,
    );

    // 최대 60초 후 자동 중지
    Future.delayed(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        _speech.stop();
        completer.completeError('timeout');
      }
    });

    try {
      final text = await completer.future;
      await _speech.stop();
      return text;
    } catch (e) {
      print('STT transcribe 예외: $e');
      return null;
    }
  }

  /// (옵션) 외부에서 강제 중지할 때
  Future<void> stop() => _speech.stop();
}
