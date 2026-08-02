import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/biometric_auth_service.dart';
import '../../core/security/pin_store.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  final _biometrics = BiometricAuthService(LocalAuthentication());
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryBiometricUnlock();
  }

  Future<void> _tryBiometricUnlock() async {
    if (await _biometrics.isAvailable()) {
      final ok = await _biometrics.authenticate(
        reason: 'auth.biometric_reason'.tr(),
      );
      if (ok && mounted) context.go('/dashboard');
    }
  }

  Future<void> _submitPin() async {
    final ok = await PinStore.verifyPin(_pinController.text);
    if (ok) {
      if (mounted) context.go('/dashboard');
    } else {
      setState(() => _error = 'auth.wrong_pin'.tr());
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('auth.unlock_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(labelText: 'auth.pin'.tr()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _submitPin, child: Text('auth.unlock'.tr())),
              TextButton(
                onPressed: _tryBiometricUnlock,
                child: Text('auth.use_biometric'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
