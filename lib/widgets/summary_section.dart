// lib/widgets/summary_section.dart

import 'package:flutter/material.dart';
import '../models/summary_item.dart';
import '../services/emoji_assets.dart';

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

    if (items.isEmpty) {
      return const Text(
        '요약 정보가 없습니다.',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        // 1) 텍스트에서 [코드] 전체를 찾아 리스트로 뽑아냄
        final codes = RegExp(r'\[(.*?)\]')
            .allMatches(item.text)
            .map((m) => m.group(1)!)
            .toList();

        // 2) 모든 [코드] 태그를 제거한 순수 텍스트
        final displayText = item.text.replaceAll(RegExp(r'\[.*?\]\s*'), '');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3) 코드 목록이 비어있지 않으면 폴더에 있는 SVG들을 순서대로 렌더링
              if (codes.isNotEmpty)
                Row(
                  children: codes.map((code) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: EmojiAssetManager.svgIcon(
                        code,
                        width: iconSize,
                        height: iconSize,
                      ),
                    );
                  }).toList(),
                )
              else
                // 코드가 없으면 기본 아이콘 하나
                Icon(Icons.emoji_emotions, size: iconSize),

              const SizedBox(width: 8),

              // 4) 남은 텍스트
              Expanded(
                child: Text(
                  displayText,
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
