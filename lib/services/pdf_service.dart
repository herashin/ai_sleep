// lib/services/pdf_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// 진료 요약 PDF 생성 및 인쇄/공유 서비스
class PDFService {
  final Uint8List _krFontBytes;
  final Uint8List _emojiFontBytes;

  PDFService._(this._krFontBytes, this._emojiFontBytes);

  /// 폰트 바이트 로드 후 초기화
  static Future<PDFService> init() async {
    try {
      final krData = await rootBundle
          .load('assets/fonts/NotoSansKR-VariableFont_wght.ttf');
      final krBytes = krData.buffer.asUint8List();
      final emojiData =
          await rootBundle.load('assets/fonts/NotoColorEmoji-Regular.ttf');
      final emojiBytes = emojiData.buffer.asUint8List();
      return PDFService._(krBytes, emojiBytes);
    } catch (e) {
      throw Exception('폰트 로딩 실패: $e');
    }
  }

  /// PDF 생성
  Future<File> generatePdf({
    required String patientName,
    required String summaryText,
  }) async {
    try {
      final pdfBytes = await compute(_buildPdfBytes, {
        'krFont': _krFontBytes,
        'emojiFont': _emojiFontBytes,
        'summaryText': summaryText,
        'patientName': patientName,
      });

      final baseDir = Directory('/storage/emulated/0/AI_Sleep_PDFs');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final safeName = patientName.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = '진료요약_${safeName}_$timestamp.pdf';
      final filePath = '${baseDir.path}/$filename';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes);
      return file;
    } catch (e, stack) {
      print('[PDFService] generatePdf ERROR: $e');
      print(stack);
      rethrow;
    }
  }

  /// PDF 인쇄
  Future<void> printPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  /// PDF 공유
  Future<void> sharePdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.sharePdf(
      bytes: bytes,
      filename: pdfFile.path.split('/').last,
    );
  }
}

/// compute로 실행되는 PDF 바이트 생성 함수
Future<Uint8List> _buildPdfBytes(Map<String, dynamic> params) async {
  final krBytes = params['krFont'] as Uint8List;
  final emojiBytes = params['emojiFont'] as Uint8List;
  final summaryText = params['summaryText'] as String;
  final patientName = params['patientName'] as String;

  final krFontData = ByteData.view(krBytes.buffer);
  final emojiFontData = ByteData.view(emojiBytes.buffer);
  final krFont = pw.Font.ttf(krFontData);
  final emojiFont = pw.Font.ttf(emojiFontData);

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) => [
        pw.Text(
          '📋 SleepVoice AI 진료카드',
          style: pw.TextStyle(
            font: krFont,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            fontFallback: [emojiFont],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          '👤 환자명: $patientName',
          style: pw.TextStyle(
            font: krFont,
            fontSize: 16,
            fontFallback: [emojiFont],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          '✏️ AI 요약:',
          style: pw.TextStyle(
            font: krFont,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            fontFallback: [emojiFont],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          summaryText,
          style: pw.TextStyle(
            font: krFont,
            fontSize: 16,
            fontFallback: [emojiFont],
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}
