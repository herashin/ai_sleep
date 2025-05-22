import 'package:flutter/foundation.dart';
import 'summary_item.dart';

/// 녹음 및 요약 결과 메타데이터 모델
@immutable
class Recording {
  final String audioPath;
  final String patientName;
  final String originalText;
  final List<Map<String, dynamic>>? speakers;
  final List<SummaryItem> summaryItems;
  final DateTime createdAt;
  final List<String> labeledTexts; // (기존 호환)
  final List<Map<String, dynamic>> dialogues; // ★ 추가!

  const Recording({
    required this.audioPath,
    required this.patientName,
    required this.originalText,
    this.speakers,
    required this.summaryItems,
    required this.createdAt,
    this.labeledTexts = const [],
    this.dialogues = const [], // ★ 기본값 추가
  });

  Recording copyWith({
    String? audioPath,
    String? patientName,
    String? originalText,
    List<Map<String, dynamic>>? speakers,
    List<SummaryItem>? summaryItems,
    DateTime? createdAt,
    List<String>? labeledTexts,
    List<Map<String, dynamic>>? dialogues, // ★ 추가
  }) {
    return Recording(
      audioPath: audioPath ?? this.audioPath,
      patientName: patientName ?? this.patientName,
      originalText: originalText ?? this.originalText,
      speakers: speakers ?? this.speakers,
      summaryItems: summaryItems ?? this.summaryItems,
      createdAt: createdAt ?? this.createdAt,
      labeledTexts: labeledTexts ?? this.labeledTexts,
      dialogues: dialogues ?? this.dialogues, // ★ 추가
    );
  }

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

    final rawSpeakers = map['speakers'];
    final parsedSpeakers = (rawSpeakers is List)
        ? rawSpeakers.whereType<Map<String, dynamic>>().toList()
        : null;

    final rawLabeledTexts = map['labeledTexts'];
    final parsedLabeledTexts = (rawLabeledTexts is List)
        ? rawLabeledTexts.map((e) => e.toString()).toList()
        : <String>[];

    // ★ dialogues 파싱
    final rawDialogues = map['dialogues'];
    final parsedDialogues = (rawDialogues is List)
        ? rawDialogues.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    return Recording(
      audioPath: map['audioPath'] as String? ?? '',
      patientName: map['patientName'] as String? ?? 'unknown',
      originalText: map['originalText'] as String? ?? '',
      speakers: parsedSpeakers,
      summaryItems: items,
      createdAt: parsedDate,
      labeledTexts: parsedLabeledTexts,
      dialogues: parsedDialogues, // ★ 추가
    );
  }

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'patientName': patientName,
        'originalText': originalText,
        'createdAt': createdAt.toIso8601String(),
        'summaryItems': summaryItems.map((e) => e.toJson()).toList(),
        'speakers': speakers,
        'labeledTexts': labeledTexts,
        'dialogues': dialogues, // ★ 추가
      };
}
