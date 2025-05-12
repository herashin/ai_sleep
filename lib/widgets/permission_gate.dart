// lib/widgets/permission_gate.dart

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
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // 초기 상태 리셋
    if (mounted) {
      setState(() {
        _allGranted = false;
        _denied = false;
      });
    }

    // 1) 마이크 권한
    if (widget.requireMicrophone) {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          _onDenied();
          return;
        }
      }
    }

    // 2) 저장소 권한
    if (widget.requireStorage) {
      final granted = await _requestStoragePermission();
      if (!granted) {
        _onDenied();
        return;
      }
    }

    // 3) 모든 권한 허용됨
    if (mounted) {
      setState(() {
        _allGranted = true;
        _denied = false;
      });
    }
  }

  void _onDenied() {
    if (mounted) {
      setState(() {
        _allGranted = false;
        _denied = true;
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdk = androidInfo.version.sdkInt ?? 0;

    if (sdk >= 33) {
      // Android 13 이상: 모든 파일 접근 요청
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    } else if (sdk >= 30) {
      // Android 11~12
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
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
    debugPrint(
        '🔒 PermissionGate build: allGranted=$_allGranted, denied=$_denied');
    if (_allGranted) {
      // 모든 권한 허용 시
      return widget.child;
    }
    if (_denied) {
      // 권한 거부 시: 다시 요청 버튼
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('앱 사용을 위해 필요한 권한이 거부되었습니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkAndRequestPermissions,
                child: const Text('권한 다시 요청'),
              ),
            ],
          ),
        ),
      );
    }
    // 초기 로딩 또는 권한 요청 중
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
