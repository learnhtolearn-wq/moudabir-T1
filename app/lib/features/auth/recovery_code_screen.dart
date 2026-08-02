import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a freshly generated recovery code exactly once. The caller decides
/// what happens next (go to dashboard after setup, pop back to Settings
/// after a manual regenerate) via [onContinue]. Blocks the back gesture —
/// the user must explicitly acknowledge they've saved the code.
///
/// [onContinue] receives this screen's own [BuildContext] rather than
/// closing over the caller's — callers that reach this screen via
/// `pushReplacement` (PIN setup, forgot-PIN reset) have a context that's
/// already disposed by the time the user taps Continue, which made the
/// button silently do nothing.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({
    super.key,
    required this.code,
    required this.onContinue,
  });

  final String code;
  final void Function(BuildContext context) onContinue;

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'auth.recovery_code_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'auth.recovery_code_body'.tr(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    child: SelectableText(
                      widget.code,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(letterSpacing: 2),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('auth.recovery_code_copied'.tr())),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: Text('auth.recovery_code_copy'.tr()),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  title: Text('auth.recovery_code_ack'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _acknowledged
                      ? () => widget.onContinue(context)
                      : null,
                  child: Text('auth.recovery_code_continue'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
