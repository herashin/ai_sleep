import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/speech/v1.dart';
import 'package:googleapis/storage/v1.dart' as gcs;
import 'package:googleapis_auth/auth_io.dart';

class GoogleSTTService {
  final _scopes = [
    SpeechApi.cloudPlatformScope,
    gcs.StorageApi.devstorageFullControlScope,
  ];

  // 🔄 전체 흐름을 처리하는 통합 함수
  Future<String?> transcribeViaGCS(File audioFile, String bucketName) async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/mineral-battery-459905-i3-27ecd47986ab.json');
      final creds = ServiceAccountCredentials.fromJson(jsonStr);

      final gcsUri = await _uploadToGCS(audioFile, creds, bucketName);
      return await _transcribeFromGCS(gcsUri, creds);
    } catch (e) {
      print('❌ 전체 STT 처리 중 오류: $e');
      return null;
    }
  }

  // 📤 GCS 업로드
  Future<String> _uploadToGCS(
      File file, ServiceAccountCredentials creds, String bucketName) async {
    final client = await clientViaServiceAccount(
        creds, [gcs.StorageApi.devstorageFullControlScope]);
    final storageApi = gcs.StorageApi(client);

    final objectName = file.uri.pathSegments.last;
    final media = gcs.Media(file.openRead(), file.lengthSync());

    await storageApi.objects.insert(
      gcs.Object()..name = objectName,
      bucketName,
      uploadMedia: media,
    );

    client.close();
    print('✅ GCS 업로드 완료: gs://$bucketName/$objectName');
    return 'gs://$bucketName/$objectName';
  }

  // 🧠 GCS 기반 STT 요청 (LongRunningRecognize)
  Future<String?> _transcribeFromGCS(
      String gcsUri, ServiceAccountCredentials creds) async {
    final client =
        await clientViaServiceAccount(creds, [SpeechApi.cloudPlatformScope]);
    final speechApi = SpeechApi(client);

    final request = LongRunningRecognizeRequest.fromJson({
      'config': {
        'encoding': 'FLAC',
        'sampleRateHertz': 16000,
        'languageCode': 'ko-KR',
        'enableSpeakerDiarization': true,
        'minSpeakerCount': 2,
        'maxSpeakerCount': 3,
        'model': 'latest_long ',
      },
      'audio': {
        'uri': gcsUri,
      },
    });

    final operation = await speechApi.speech.longrunningrecognize(request);
    final opName = operation.name!;

    // 🔁 대기 루프 (폴링)
    while (true) {
      final result = await speechApi.operations.get(opName);
      if (result.done == true) {
        final json = result.toJson();

        // response → results → alternatives → transcript
        final responseData = json['response'];
        final results = responseData['results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final firstAlternative = results.first['alternatives'][0];

          // 🗣️ 화자 분석된 단어 목록이 있을 경우
          final words = firstAlternative['words'] as List<dynamic>?;

          if (words != null && words.isNotEmpty) {
            final buffer = StringBuffer();
            int currentSpeaker = words.first['speakerTag'];
            buffer.write('화자$currentSpeaker: ');

            for (var word in words) {
              final speaker = word['speakerTag'];
              final w = word['word'];
              if (speaker != currentSpeaker) {
                currentSpeaker = speaker;
                buffer.write('\n화자$currentSpeaker: ');
              }
              buffer.write('$w ');
            }

            return buffer.toString().trim();
          } else {
            // 화자 정보 없으면 기본 텍스트 추출
            return firstAlternative['transcript'];
          }
        }
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
