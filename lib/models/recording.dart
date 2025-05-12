// lib/models/recording.dart

import 'package:flutter/foundation.dart';
import 'summary_item.dart';

class Recording {
  final String audioPath;
  final String originalText;
  final List<SummaryItem> summaryItems; // 변경된 부분
  final DateTime createdAt;
  final String patientName;

  Recording({
    required this.audioPath,
    required this.originalText,
    required this.summaryItems,
    required this.createdAt,
    required this.patientName,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    // 1) audioPath, originalText, patientName: 누락 시 빈 문자열로 대체
    final audioPath = json['audioPath']?.toString() ?? '';
    final originalText = json['originalText']?.toString() ?? '';
    final patientName = json['patientName']?.toString() ?? '';

    // 2) createdAt: 파싱이 실패하면 현재 시간으로 대체
    DateTime createdAt;
    try {
      final rawDate = json['createdAt']?.toString() ?? '';
      createdAt = DateTime.parse(rawDate);
    } catch (_) {
      createdAt = DateTime.now();
    }

    // 3) summaryItems: 리스트·맵 여부, 내부 필드 검사
    final rawItems = json['summaryItems'];
    final List<SummaryItem> safeItems = [];
    if (rawItems is List) {
      for (var e in rawItems) {
        if (e is Map<String, dynamic>) {
          final iconCode = e['iconCode']?.toString() ?? '';
          final text = e['text']?.toString() ?? '';
          safeItems.add(SummaryItem(iconCode: iconCode, text: text));
        }
      }
    }
    // (null이거나 List가 아니면 빈 리스트)

    return Recording(
      audioPath: audioPath,
      originalText: originalText,
      summaryItems: safeItems,
      createdAt: createdAt,
      patientName: patientName,
    );
  }

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'originalText': originalText,
        'summaryItems': summaryItems
            .map((i) => {'iconCode': i.iconCode, 'text': i.text})
            .toList(),
        'createdAt': createdAt.toIso8601String(),
        'patientName': patientName,
      };
}
