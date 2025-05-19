import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/speech/v1.dart';
import 'package:googleapis/storage/v1.dart' as gcs;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';

class GoogleSTTService {
  final _scopes = [
    SpeechApi.cloudPlatformScope,
    gcs.StorageApi.devstorageFullControlScope,
  ];

  Future<String?> transcribeViaGCS(File audioFile, String bucketName) async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/mineral-battery-459905-i3-27ecd47986ab.json');
      final creds = ServiceAccountCredentials.fromJson(jsonStr);

      final gcsUri = await _uploadToGCS(audioFile, creds, bucketName);
      return await _transcribeFromGCS(gcsUri, creds);
    } catch (e) {
      debugPrint('❌ 전체 STT 처리 중 오류: $e');
      return null;
    }
  }

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
    debugPrint('✅ GCS 업로드 완료: gs://$bucketName/$objectName');
    return 'gs://$bucketName/$objectName';
  }

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
        'enableAutomaticPunctuation': true,
        'useEnhanced': false,
        'model': 'latest_long',
        'enableSpeakerDiarization': true,
        'diarizationConfig': {
          'enableSpeakerDiarization': true,
          'minSpeakerCount': 2,
          'maxSpeakerCount': 3,
        },
        'enableWordTimeOffsets': true,
      },
      'audio': {'uri': gcsUri},
    });

    final operation = await speechApi.speech.longrunningrecognize(request);
    final opName = operation.name!;
    const maxAttempts = 30;
    int attempts = 0;

    while (attempts < maxAttempts) {
      final result = await speechApi.operations.get(opName);
      if (result.done == true) {
        if (result.error != null) {
          debugPrint(
              '❌ STT API 에러 발생: ${result.error!.code}, ${result.error!.message}');
          return null;
        }

        final json = result.toJson();
        final responseData = json['response'] as Map<String, dynamic>?;

        if (responseData == null) {
          debugPrint('⚠️ STT 응답이 비어있습니다.');
          return null;
        }

        final results = responseData['results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final buffer = StringBuffer();
          final Set<String> seenSentences = {};

          for (var result in results) {
            final alternative = result['alternatives'][0];
            final words = alternative['words'] as List<dynamic>?;

            String text;

            if (words != null && words.isNotEmpty) {
              // words로 화자별 문장 조립
              final sentenceBuffer = StringBuffer();
              int lastSpeakerTag = words.first['speakerTag'] ?? 1;
              sentenceBuffer.write('(화자$lastSpeakerTag) ');

              for (var word in words) {
                final speaker = word['speakerTag'] ?? lastSpeakerTag;
                final w = word['word'];

                if (speaker != lastSpeakerTag) {
                  sentenceBuffer.write('\n(화자$speaker) ');
                  lastSpeakerTag = speaker;
                }
                sentenceBuffer.write('$w ');
              }
              text = sentenceBuffer.toString().trim();
            } else {
              // words가 없을 때만 transcript 사용
              text = alternative['transcript'].toString().trim();
            }

            // 문장 전체 단위로만 중복 제거
            if (text.isNotEmpty && !seenSentences.contains(text)) {
              seenSentences.add(text);
              buffer.writeln(text);
            }
          }

          // 최종 결과 정리 (불필요한 특수문자/공백/숫자-문자 분리 등 후처리)
          String cleanResult = buffer
              .toString()
              .replaceAll(RegExp(r'▁'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAllMapped(
                  RegExp(r'(\d+)([가-힣a-zA-Z])'), (m) => '${m[1]} ${m[2]}')
              .replaceAllMapped(
                  RegExp(r'([가-힣a-zA-Z])(\d+)'), (m) => '${m[1]} ${m[2]}')
              .trim();

          return cleanResult;
        } else {
          debugPrint('⚠️ STT 결과가 없습니다.');
          return null;
        }
      }
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
    }
    debugPrint('⚠️ STT 처리 시간이 초과되었습니다.');
    return null;
  }
}
