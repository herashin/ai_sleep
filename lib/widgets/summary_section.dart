// lib/widgets/summary_section.dart

import 'package:flutter/material.dart';
import '../models/summary_item.dart';
import '../services/emoji_assets.dart';

/// SummaryItem 리스트를 받아 [Row(icon, text), …] 형태로 그려주는 위젯
class SummarySection extends StatelessWidget {
  final List<SummaryItem> items;
  final double iconSize;
  final TextStyle? textStyle;

  const SummarySection({
    Key? key,
    required this.items,
    this.iconSize = 24,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 비동기 없이 바로 SVG asset 로드
              EmojiAssetManager.svgIcon(
                item.iconCode,
                width: iconSize,
                height: iconSize,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.text,
                  style: textStyle ?? defaultStyle,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
