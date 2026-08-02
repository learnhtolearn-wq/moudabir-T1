import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import 'accounts_screen.dart' show accountTypes;
import 'providers/accounts_provider.dart';

class AccountsFormScreen extends ConsumerStatefulWidget {
  const AccountsFormScreen({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountsFormScreen> createState() =>
      _AccountsFormScreenState();
}

class _AccountsFormScreenState extends ConsumerState<AccountsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _currencyController;
  late String _type;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _balanceController = TextEditingController(
      text: account != null ? account.initialBalance.toString() : '0',
    );
    _currencyController =
        TextEditingController(text: account?.currency ?? 'MAD');
    _type = account?.type ?? accountTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(accountsNotifierProvider);
    final name = _nameController.text.trim();
    final currency = _currencyController.text.trim();
    final balance = double.parse(_balanceController.text.trim());

    if (_isEditing) {
      await notifier.update(
        widget.account!.copyWith(
          name: name,
          type: _type,
          currency: currency,
          initialBalance: balance,
        ),
      );
    } else {
      await notifier.add(
        name: name,
        type: _type,
        currency: currency,
        initialBalance: balance,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('accounts.archive_title'.tr()),
        content: Text('accounts.archive_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(accountsNotifierProvider).archive(widget.account!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'accounts.edit_title'.tr() : 'accounts.add_title'.tr()),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _archive,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'accounts.name'.tr()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'common.required'.tr() : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: 'accounts.type_label'.tr()),
              items: accountTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text('accounts.type.$t'.tr()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currencyController,
              decoration: InputDecoration(labelText: 'accounts.currency'.tr()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'common.required'.tr() : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceController,
              decoration:
                  InputDecoration(labelText: 'accounts.initial_balance'.tr()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'common.required'.tr();
                return double.tryParse(v.trim()) == null
                    ? 'common.invalid_number'.tr()
                    : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
