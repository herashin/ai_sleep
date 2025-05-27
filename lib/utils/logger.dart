import 'dart:io';

class Logger {
  static final Logger _instance = Logger._internal();
  late File _logFile;

  factory Logger() => _instance;

  Logger._internal();

  Future<void> init() async {
    // 기존 getExternalStorageDirectory() 대신 직접 경로 지정
    final dir = Directory('/storage/emulated/0/AI_Sleep_log');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _logFile = File('${dir.path}/record_log.txt');
    if (!(await _logFile.exists())) {
      await _logFile.create(recursive: true);
    }
  }

  Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    await _logFile.writeAsString('$timestamp: $message\n',
        mode: FileMode.append);
  }
}
