import 'package:flutter/material.dart';
import '../models/recording.dart';
import 'package:intl/intl.dart';

class RecordingListItem extends StatelessWidget {
  final Recording rec;
  final VoidCallback onTap;

  const RecordingListItem({
    Key? key,
    required this.rec,
    required this.onTap,
  }) : super(key: key);

  static final _formatter = DateFormat('yyyy.MM.dd HH:mm');

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.audiotrack, color: Colors.teal),
        title: Text('${rec.patientName} 환자 진료상담 요약'),
        subtitle: Text(_formatter.format(rec.createdAt)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
