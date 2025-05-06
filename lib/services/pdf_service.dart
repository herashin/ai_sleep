// PDF generator
// lib/services/pdf_service.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

/// 진료 요약 PDF 생성 및 공유 서비스
class PDFService {
  /// 요약 텍스트를 받아 PDF 파일로 생성
  Future<File> generatePdf(String summaryText) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SleepVoice AI 진료카드',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  summaryText,
                  style: pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );

    // 임시 디렉터리에 파일 저장
    final outputDir = await getTemporaryDirectory();
    final file = File(
      '${outputDir.path}/summary_${DateTime.now().millisecondsSinceEpoch}.pdf'
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 생성된 PDF 파일을 공유하거나 인쇄
  Future<void> printOrSharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }
}