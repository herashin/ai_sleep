// lib/screens/permission_helper.dart

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 권한 요청 및 관리 헬퍼 클래스
class PermissionHelper {
  bool _requestInProgress = false; // 중복 요청 방지용 플래그

  /// 마이크, 저장소 권한 등 필요한 권한을 체크하고 요청
  /// 권한이 모두 허용되면 true 반환, 아니면 false 반환
  Future<bool> checkAndRequestPermissions({
    bool requireMicrophone = false,
    bool requireStorage = false,
  }) async {
    if (_requestInProgress) return false; // 이미 요청 중이면 바로 false 리턴
    _requestInProgress = true;

    try {
      // 1) 마이크 권한 요청
      if (requireMicrophone) {
        var micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          micStatus = await Permission.microphone.request();
          if (!micStatus.isGranted) {
            return false;
          }
        }
      }

      // 2) 저장소 권한 요청
      if (requireStorage) {
        final granted = await _requestStoragePermission();
        if (!granted) {
          return false;
        }
      }

      return true; // 모든 권한 허용
    } finally {
      _requestInProgress = false; // 요청 완료 상태로 변경
    }
  }

  /// 저장소 권한을 Android 버전에 맞게 요청
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true; // Android 아니면 항상 true

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdk = androidInfo.version.sdkInt;

    if (sdk >= 33) {
      // Android 13 이상
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
}
