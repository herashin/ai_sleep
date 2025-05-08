// lib/models/recording.dart

class Recording {
  final String audioPath; // 저장경로
  final String originalText;
  final String summaryText;
  final DateTime createdAt;
  final String patientName; // 환자이름

  Recording({
    required this.audioPath, // 저장경로
    required this.originalText,
    required this.summaryText,
    required this.createdAt,
    required this.patientName, // 환자이름
  });
}
