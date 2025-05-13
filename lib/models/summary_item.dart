// lib/models/summary_item.dart

class SummaryItem {
  final String iconCode;
  final String text;

  SummaryItem({
    required this.iconCode,
    required this.text,
  });

  /// JSON → SummaryItem
  factory SummaryItem.fromJson(Map<String, dynamic> json) {
    return SummaryItem(
      iconCode: json['iconCode'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  /// SummaryItem → JSON
  Map<String, dynamic> toJson() => {
        'iconCode': iconCode,
        'text': text,
      };
}
