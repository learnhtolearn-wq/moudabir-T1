import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/security/biometric_auth_service.dart';
import '../../core/security/pin_store.dart';
import 'forgot_pin_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  final _biometrics = BiometricAuthService(LocalAuthentication());
  String? _error;
  Duration? _lockoutRemaining;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
    _tryBiometricUnlock();
  }

  Future<void> _checkLockout() async {
    final remaining = await PinStore.lockoutRemaining();
    if (!mounted) return;
    setState(() => _lockoutRemaining = remaining);
    _lockoutTimer?.cancel();
    if (remaining != null) {
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _checkLockout();
      });
    }
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
      await _checkLockout();
      if (!mounted) return;
      setState(() {
        _error = _lockoutRemaining != null
            ? 'auth.locked_out'.tr(
                namedArgs: {'seconds': '${_lockoutRemaining!.inSeconds}'},
              )
            : 'auth.wrong_pin'.tr();
      });
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockoutRemaining != null;
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
                enabled: !locked,
                decoration: InputDecoration(labelText: 'auth.pin'.tr()),
              ),
              if (locked) ...[
                const SizedBox(height: 8),
                Text(
                  'auth.locked_out'.tr(
                    namedArgs: {'seconds': '${_lockoutRemaining!.inSeconds}'},
                  ),
                  style: const TextStyle(color: Colors.red),
                ),
              ] else if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: locked ? null : _submitPin,
                child: Text('auth.unlock'.tr()),
              ),
              TextButton(
                onPressed: _tryBiometricUnlock,
                child: Text('auth.use_biometric'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .push(MaterialPageRoute(
                        builder: (_) => const ForgotPinScreen())),
                child: Text('auth.forgot_pin'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
