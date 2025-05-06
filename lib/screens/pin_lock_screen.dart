// PIN lock screen UI
// lib/screens/pin_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 플러터 시크릿 스토리지 인스턴스
final FlutterSecureStorage storage = FlutterSecureStorage();

/// PIN 잠금 화면 위젯
/// [child]에 전달된 위젯으로 잠금 해제 후 이동합니다.
class PinLockScreen extends StatefulWidget {
  final Widget child;
  
  const PinLockScreen({super.key, required this.child});
  
  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _storedPin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  /// 저장된 PIN을 불러오고, 없으면 기본값(‘1234’)을 저장합니다.
  Future<void> _loadStoredPin() async {
    _storedPin = await storage.read(key: 'user_pin');
    if (_storedPin == null) {
      await storage.write(key: 'user_pin', value: '1234');
      _storedPin = '1234';
    }
    setState(() => _isLoading = false);
  }

  /// 입력한 PIN이 저장된 값과 맞는지 검증합니다.
  void _validatePin() {
    if (_pinController.text == _storedPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.child),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ PIN 번호가 일치하지 않습니다')),
      );
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 260,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '앱 잠금 해제',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'PIN 입력 (예: 1234)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _validatePin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('잠금 해제', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
