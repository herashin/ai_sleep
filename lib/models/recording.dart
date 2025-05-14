// lib/models/recording.dart

import 'package:flutter/foundation.dart';
import 'summary_item.dart';

/// 녹음 및 요약 결과 메타데이터 모델
@immutable
class Recording {
  final String audioPath;
  final String patientName;
  final String originalText;
  final List<SummaryItem> summaryItems;
  final DateTime createdAt;

  const Recording({
    required this.audioPath,
    required this.patientName,
    required this.originalText,
    required this.summaryItems,
    required this.createdAt,
  });

  /// 객체 복사본을 일부 필드만 변경해 생성
  Recording copyWith({
    String? audioPath,
    String? patientName,
    String? originalText,
    List<SummaryItem>? summaryItems,
    DateTime? createdAt,
  }) {
    return Recording(
      audioPath: audioPath ?? this.audioPath,
      patientName: patientName ?? this.patientName,
      originalText: originalText ?? this.originalText,
      summaryItems: summaryItems ?? this.summaryItems,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// JSON → Recording 객체
  factory Recording.fromJson(Map<String, dynamic> map) {
    final createdAtStr = map['createdAt'] as String? ?? '';
    final parsedDate = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    List<SummaryItem> items = [];
    final rawItems = map['summaryItems'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => SummaryItem.fromJson(e))
          .toList();
    }

    return Recording(
      audioPath: map['audioPath'] as String? ?? '',
      patientName: map['patientName'] as String? ?? 'unknown',
      originalText: map['originalText'] as String? ?? '',
      summaryItems: items,
      createdAt: parsedDate,
    );
  }

  /// Recording 객체 → JSON
  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'patientName': patientName,
        'originalText': originalText,
        'createdAt': createdAt.toIso8601String(),
        'summaryItems': summaryItems.map((e) => e.toJson()).toList(),
      };
}
