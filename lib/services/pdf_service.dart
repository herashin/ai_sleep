// lib/services/pdf_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/summary_item.dart';
import 'emoji_assets.dart';

class PDFService {
  final Uint8List _krFontBytes;
  final Map<String, String> _svgs;

  PDFService._(this._krFontBytes, this._svgs);

  /// SVG 키 목록으로 초기화
  static Future<PDFService> init({List<String>? keys}) async {
    final svgKeys = keys ?? ['1f4cb', '1f464', '270f'];

    // 한글 폰트 로드
    final krData =
        await rootBundle.load('assets/fonts/NotoSansKR-VariableFont_wght.ttf');
    final krBytes = krData.buffer.asUint8List();

    // SVG 로드
    final svgs = <String, String>{};
    for (final key in svgKeys) {
      try {
        svgs[key] = await EmojiAssetManager.loadSvg(key);
      } catch (_) {
        svgs[key] = '';
      }
    }

    return PDFService._(krBytes, svgs);
  }

  /// 환자명과 SummaryItem 리스트를 받아 PDF 파일 생성
  Future<File> generatePdf({
    required String patientName,
    required List<SummaryItem> summaryItems,
  }) async {
    if (Platform.isAndroid &&
        !await Permission.manageExternalStorage.isGranted) {
      throw Exception('MANAGE_EXTERNAL_STORAGE 권한이 필요합니다.');
    }

    // compute로 바이트 생성
    final pdfBytes = await compute(_buildPdfBytes, {
      'krFont': _krFontBytes,
      'svgs': _svgs,
      'patientName': patientName,
      'items': summaryItems
          .map((e) => {'iconCode': e.iconCode, 'text': e.text})
          .toList(),
    });

    // 저장 디렉토리 준비
    final baseDir = Directory('/storage/emulated/0/AI_Sleep_PDFs');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    final safeName = patientName.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${baseDir.path}/진료요약_${safeName}_$timestamp.pdf');

    await file.writeAsBytes(pdfBytes);
    return file;
  }

  Future<void> printPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> sharePdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.sharePdf(
      bytes: bytes,
      filename: pdfFile.path.split('/').last,
    );
  }
}

/// isolate에서 실행되는 PDF 바이트 생성 함수
Future<Uint8List> _buildPdfBytes(Map<String, dynamic> params) async {
  final krBytes = params['krFont'] as Uint8List;
  final svgs = Map<String, String>.from(params['svgs'] as Map);
  final patientName = params['patientName'] as String;
  final items = List<Map<String, dynamic>>.from(params['items'] as List);

  final krFont = pw.Font.ttf(ByteData.view(krBytes.buffer));
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        // 헤더
        pw.Row(children: [
          if ((svgs[items.first['iconCode']] ?? '').isNotEmpty)
            pw.SvgImage(
                svg: svgs[items.first['iconCode']]!, width: 24, height: 24),
          pw.SizedBox(width: 8),
          pw.Text(
            'SleepVoice AI 진료카드',
            style: pw.TextStyle(
                font: krFont, fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ]),
        pw.SizedBox(height: 16),
        // 환자명
        pw.Row(children: [
          if ((svgs['1f464'] ?? '').isNotEmpty)
            pw.SvgImage(svg: svgs['1f464']!, width: 20, height: 20),
          if ((svgs['1f464'] ?? '').isNotEmpty) pw.SizedBox(width: 6),
          pw.Text('환자명: $patientName',
              style: pw.TextStyle(font: krFont, fontSize: 16)),
        ]),
        pw.SizedBox(height: 16),
        // AI 요약
        pw.Row(children: [
          if ((svgs['270f'] ?? '').isNotEmpty)
            pw.SvgImage(svg: svgs['270f']!, width: 20, height: 20),
          if ((svgs['270f'] ?? '').isNotEmpty) pw.SizedBox(width: 6),
          pw.Text('AI 요약:',
              style: pw.TextStyle(
                  font: krFont, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 8),
        // SummaryItem 기반 줄별 아이콘+텍스트
        ...items.map((item) {
          final svgStr = svgs[item['iconCode']] ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (svgStr.isNotEmpty)
                  pw.SvgImage(svg: svgStr, width: 20, height: 20),
                if (svgStr.isNotEmpty) pw.SizedBox(width: 6),
                pw.Expanded(
                    child: pw.Text(item['text'],
                        style: pw.TextStyle(font: krFont, fontSize: 14))),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );

  return pdf.save();
}
