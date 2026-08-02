import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/pin_store.dart';
import 'recovery_code_screen.dart';

/// Offline PIN recovery: enter the one-time recovery code shown at setup,
/// then choose a new PIN. On success a fresh recovery code is generated —
/// the old one was just spent and shouldn't stay valid.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeVerified = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final ok = await PinStore.verifyRecoveryCode(_codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _codeVerified = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'auth.recovery_code_invalid'.tr());
    }
  }

  Future<void> _setNewPin() async {
    final pin = _pinController.text;
    final confirm = _confirmController.text;

    if (pin.length < 4) {
      setState(() => _error = 'auth.pin_too_short'.tr());
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'auth.pin_mismatch'.tr());
      return;
    }

    await PinStore.setPin(pin);
    final code = await PinStore.regenerateRecoveryCode();
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecoveryCodeScreen(
          code: code,
          onContinue: (ctx) => ctx.go('/dashboard'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.forgot_pin_title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _codeVerified
                ? _newPinFields(context)
                : _codeEntryFields(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _codeEntryFields(BuildContext context) {
    return [
      Text(
        'auth.forgot_pin_body'.tr(),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _codeController,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: 'auth.recovery_code'.tr()),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _verifyCode,
        child: Text('common.continue_label'.tr()),
      ),
    ];
  }

  List<Widget> _newPinFields(BuildContext context) {
    return [
      Text(
        'auth.setup_pin_title'.tr(),
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        decoration: InputDecoration(labelText: 'auth.pin'.tr()),
      ),
      TextField(
        controller: _confirmController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        decoration: InputDecoration(labelText: 'auth.confirm_pin'.tr()),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _setNewPin,
        child: Text('auth.save_pin'.tr()),
      ),
    ];
  }
}
