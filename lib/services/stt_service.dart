// lib/services/stt_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 네이티브 음성인식을 래핑한 STT 서비스
class STTService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  /// 인식된 텍스트를 저장
  String recognizedText = '';

  /// 초기화: 권한 요청 및 엔진 초기화
  Future init() async {
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

  /// 녹음(인식) 시작
  Future startListening() async {
    if (!_initialized && !await init()) return;
    recognizedText = '';
    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          recognizedText = result.recognizedWords;
        }
      },
      localeId: 'ko_KR',
      listenMode: ListenMode.dictation,
    );
  }

  /// 녹음(인식) 중지
  Future stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// (옵션) 강제 중지 alias
  Future stop() => stopListening();
}
