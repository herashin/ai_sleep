// Invoice PDF generator
// lib/services/invoice_service.dart

import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class InvoiceService {
  /// 진료비 청구서 PDF 생성
  Future<File> generateInvoicePDF({
    required String patientName,
    required String chartNumber,
    required String treatment,
    required String cost,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SleepVoice 진료비 청구서',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('👤 환자명: \$patientName'),
              pw.Text('🧾 차트번호: \$chartNumber'),
              pw.Text(
                  '📅 발행일: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('🦷 치료내용: \$treatment'),
              pw.Text('💰 예상 비용: \$cost'),
              pw.Text('💳 결제 방식: 미정'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text(
                '※ 본 청구서는 예상 금액이며, 실청구 시 변경될 수 있습니다.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file =
        File('\${dir.path}/invoice_\${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 생성된 PDF 파일 공유
  void shareInvoice(File file) {
    Printing.sharePdf(
        bytes: file.readAsBytesSync(), filename: file.path.split('/').last);
  }
}
