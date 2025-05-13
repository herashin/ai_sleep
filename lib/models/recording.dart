// lib/models/recording.dart

import 'package:flutter/foundation.dart';
import 'summary_item.dart';

/// 녹음 및 요약 결과 메타데이터 모델
class Recording {
  final String audioPath;
  final String patientName;
  final String originalText;
  final List<SummaryItem> summaryItems;
  final DateTime createdAt;

  Recording({
    required this.audioPath,
    required this.patientName,
    required this.originalText,
    required this.summaryItems,
    required this.createdAt,
  });

  /// JSON → Recording 객체
  factory Recording.fromJson(Map<String, dynamic> map) {
    try {
      final createdAtStr = map['createdAt'] as String? ?? '';
      final parsedDate = DateTime.tryParse(createdAtStr) ?? DateTime.now();
      final rawItems = map['summaryItems'];
      List<SummaryItem> items = [];
      if (rawItems is List) {
        items = rawItems
            .whereType<Map<String, dynamic>>()
            .map((e) => SummaryItem.fromJson(e))
            .toList();
      }

      final recording = Recording(
        audioPath: map['audioPath'] as String? ?? '',
        patientName: map['patientName'] as String? ?? 'unknown',
        originalText: map['originalText'] as String? ?? '',
        summaryItems: items,
        createdAt: parsedDate,
      );

      debugPrint(
          '✅ Recording.fromJson 성공: ${recording.patientName}, 아이템 수: ${items.length}');
      return recording;
    } catch (e, stack) {
      debugPrint('🚨 Recording.fromJson 예외 발생: $e\nstack: $stack');
      rethrow;
    }
  }

  /// Recording 객체 → JSON
  Map<String, dynamic> toJson() {
    return {
      'audioPath': audioPath,
      'patientName': patientName,
      'originalText': originalText,
      'createdAt': createdAt.toIso8601String(),
      'summaryItems': summaryItems.map((e) => e.toJson()).toList(),
    };
  }
}
