import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/security/pin_store.dart';

/// Settings → Change PIN. Requires the current PIN (not the recovery code —
/// that's the forgot-PIN path) before accepting a new one.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentOk = await PinStore.verifyPin(_currentController.text);
    if (!currentOk) {
      setState(() => _error = 'auth.wrong_pin'.tr());
      return;
    }

    final newPin = _newController.text;
    if (newPin.length < 4) {
      setState(() => _error = 'auth.pin_too_short'.tr());
      return;
    }
    if (newPin != _confirmController.text) {
      setState(() => _error = 'auth.pin_mismatch'.tr());
      return;
    }

    await PinStore.setPin(newPin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('auth.pin_changed'.tr())),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.change_pin_title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _currentController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration:
                    InputDecoration(labelText: 'auth.current_pin'.tr()),
              ),
              TextField(
                controller: _newController,
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
                decoration:
                    InputDecoration(labelText: 'auth.confirm_pin'.tr()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text('auth.save_pin'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
