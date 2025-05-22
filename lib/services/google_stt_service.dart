// google_stt_service.dart
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
          //  'minSpeakerCount': 2,
          //  'maxSpeakerCount': 3,
          'diarizationSpeakerCount': 2,
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

            if (words != null && words.isNotEmpty) {
              int lastSpeakerTag = words.first['speakerTag'] ?? 1;
              StringBuffer sentenceBuffer = StringBuffer();
              sentenceBuffer.write('(화자$lastSpeakerTag) ');

              for (var word in words) {
                final speaker = word['speakerTag'] ?? lastSpeakerTag;
                final w = word['word'];

                if (speaker != lastSpeakerTag) {
                  // 현재까지 누적된 화자 문장을 한 줄로 기록
                  String sentence = sentenceBuffer.toString().trim();
                  if (sentence.isNotEmpty &&
                      !seenSentences.contains(sentence)) {
                    seenSentences.add(sentence);
                    buffer.writeln(sentence); // ★줄바꿈은 buffer.writeln()이 책임★
                  }
                  // 새 화자로 초기화
                  sentenceBuffer = StringBuffer();
                  sentenceBuffer.write('(화자$speaker) ');
                  lastSpeakerTag = speaker;
                }
                sentenceBuffer.write('$w ');
              }
              // 마지막 화자 문장도 반드시 기록
              String sentence = sentenceBuffer.toString().trim();
              if (sentence.isNotEmpty && !seenSentences.contains(sentence)) {
                seenSentences.add(sentence);
                buffer.writeln(sentence); // ★여기도 buffer.writeln★
              }
            } else {
              // words가 없을 때만 transcript 사용
              String transcript = alternative['transcript'].toString().trim();
              if (transcript.isNotEmpty &&
                  !seenSentences.contains(transcript)) {
                seenSentences.add(transcript);
                buffer.writeln(transcript);
              }
            }
          }

          // 최종 결과 정리
          String cleanResult = buffer
              .toString()
              .replaceAll(RegExp(r'▁'), '')
              //  .replaceAll(RegExp(r'\s+'), ' ')
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
