// lib/services/emoji_assets.dart

import 'package:flutter_svg/flutter_svg.dart';

// 만약 Material 위젯을 쓴다면
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

class EmojiAssetManager {
  static const _pathPrefix = 'assets/emojis/';
  static const Map<String, String> _assets = {
    '1f4cb': '1f4cb.svg',
    '1f464': '1f464.svg',
    '270f': '270f.svg',
    '1f9b7': '1f9b7.svg',
    '1f4dd': '1f4dd.svg',
    '1f4b0': '1f4b0.svg',
    '1f5d3': '1f5d3.svg',
  };

  /// SVG 문자열을 로드하는 메서드
  static Future<String> loadSvg(String key) async {
    final fileName = _assets[key];
    if (fileName == null) throw Exception('Unknown emoji key: $key');
    return await rootBundle.loadString('$_pathPrefix$fileName');
  }

  /// key가 있으면 SvgPicture.asset으로 바로 반환
  static Widget svgIcon(
    String key, {
    double width = 24,
    double height = 24,
  }) {
    final fileName = _assets[key];
    if (fileName == null) return const SizedBox.shrink();
    return SvgPicture.asset(
      '$_pathPrefix$fileName',
      width: width,
      height: height,
    );
  }
}
