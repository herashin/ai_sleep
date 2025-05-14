// lib/widgets/pdf_export_buttons.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/recording.dart';
import '../services/pdf_service.dart';

class PDFExportButtons extends StatefulWidget {
  final Recording recording;

  const PDFExportButtons({Key? key, required this.recording}) : super(key: key);

  @override
  _PDFExportButtonsState createState() => _PDFExportButtonsState();
}

class _PDFExportButtonsState extends State<PDFExportButtons> {
  PDFService? _pdfService;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // 미리 초기화 (옵션)
    PDFService.init(
      keys: widget.recording.summaryItems.map((e) => e.iconCode).toList(),
    ).then((svc) {
      _pdfService = svc;
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDFService 초기화 실패: $e')),
      );
    });
  }

  Future<void> _exportPdf() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      // (1) 권한 체크 (Android 11+)
      if (Platform.isAndroid &&
          !await Permission.manageExternalStorage.isGranted) {
        final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('파일 접근 권한 필요'),
                content: const Text('PDF 저장을 위해 모든 파일 접근 권한이 필요합니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('설정으로')),
                ],
              ),
            ) ??
            false;
        if (!ok) {
          setState(() => _isGenerating = false);
          return;
        }
        await openAppSettings();
      }

      // (2) PDFService가 초기화되지 않았으면 다시 초기화
      final pdfSvc = _pdfService ??
          await PDFService.init(
            keys: widget.recording.summaryItems.map((e) => e.iconCode).toList(),
          );

      // (3) PDF 생성
      final file = await pdfSvc.generatePdf(
        patientName: widget.recording.patientName,
        summaryItems: widget.recording.summaryItems,
      );

      // (4) 공유 또는 인쇄
      await pdfSvc.sharePdf(file);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성·공유 완료\n${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성 오류: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('녹음 목록'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(_isGenerating ? '생성 중…' : 'PDF 출력'),
          onPressed: _isGenerating ? null : _exportPdf,
        ),
      ),
    ]);
  }
}
