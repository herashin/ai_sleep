import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 권한 체크 위젯
/// requireMicrophone: 마이크 권한 필요 여부
/// requireStorage: 저장소(파일) 권한 필요 여부
/// child: 권한이 모두 허용된 후 보여줄 화면
class PermissionGate extends StatefulWidget {
  final bool requireMicrophone;
  final bool requireStorage;
  final Widget child;

  const PermissionGate({
    Key? key,
    this.requireMicrophone = false,
    this.requireStorage = false,
    required this.child,
  }) : super(key: key);

  @override
  _PermissionGateState createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _allGranted = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // 마이크 권한 요청
    if (widget.requireMicrophone) {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          final ok = await _showSettingsDialog(
            title: '마이크 권한 필요',
            message: '마이크 권한이 필요합니다. 설정 화면으로 이동하시겠어요?',
          );
          if (ok) openAppSettings();
          return;
        }
      }
    }

    // 저장소 권한 요청
    if (widget.requireStorage) {
      final granted = await _requestStoragePermission();
      if (!granted) {
        final ok = await _showSettingsDialog(
          title: '저장소 권한 필요',
          message: '파일 저장을 위해 권한이 필요합니다. 설정 화면으로 이동하시겠어요?',
        );
        if (ok) openAppSettings();
        return;
      }
    }

    // 모든 권한 허용됨
    setState(() => _allGranted = true);
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdk = androidInfo.version.sdkInt ?? 0;

    if (sdk >= 33) {
      // Android 13 이상
      final statuses = await [
        Permission.audio,
        Permission.photos,
        Permission.videos,
      ].request();
      return statuses.values.every((status) => status.isGranted);
    } else if (sdk >= 30) {
      // Android 11~12
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      // Android 10 이하
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<bool> _showSettingsDialog({
    required String title,
    required String message,
  }) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('설정으로'),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_allGranted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
