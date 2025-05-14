import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../widgets/original_text_section.dart';
import '../widgets/ai_summary_section.dart';
import '../widgets/audio_player_section.dart';
import '../widgets/pdf_export_buttons.dart';
import '../widgets/permission_gate.dart';

class ResultScreen extends StatelessWidget {
  final Recording recording;

  const ResultScreen({Key? key, required this.recording}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      requireMicrophone: false,
      requireStorage: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('요약 결과')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OriginalTextSection(text: recording.originalText),
              const Divider(height: 32),
              AISummarySection(items: recording.summaryItems),
              const Divider(height: 32),
              AudioPlayerSection(audioPath: recording.audioPath),
              const SizedBox(height: 20),
              PDFExportButtons(recording: recording),
            ],
          ),
        ),
      ),
    );
  }
}
