import 'package:drift/drift.dart' as drift;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../accounts/providers/accounts_provider.dart';
import '../categories/providers/categories_provider.dart';
import '../transactions/transaction_form_screen.dart' show transactionTypes;
import 'providers/recurring_provider.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.template});

  final RecurringTemplate? template;

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dayController;
  late String _type;
  int? _accountId;
  int? _categoryId;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _amountController =
        TextEditingController(text: t != null ? t.amount.toString() : '');
    _dayController =
        TextEditingController(text: t != null ? t.dayOfMonth.toString() : '');
    _type = t?.type ?? 'expense';
    _accountId = t?.accountId;
    _categoryId = t?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;

    final notifier = ref.read(recurringNotifierProvider);
    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final day = int.parse(_dayController.text.trim());

    if (_isEditing) {
      await notifier.update(
        widget.template!.copyWith(
          name: name,
          type: _type,
          amount: amount,
          accountId: _accountId!,
          categoryId: drift.Value(_categoryId),
          dayOfMonth: day,
        ),
      );
    } else {
      await notifier.add(
        name: name,
        type: _type,
        amount: amount,
        accountId: _accountId!,
        categoryId: _categoryId,
        dayOfMonth: day,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('recurring.delete_title'.tr()),
        content: Text('recurring.delete_confirm'.tr()),
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
      await ref.read(recurringNotifierProvider).delete(widget.template!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEditing ? 'recurring.edit_title'.tr() : 'recurring.add_title'.tr()),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppTextField(
              controller: _nameController,
              label: 'recurring.name'.tr(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'common.required'.tr() : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: transactionTypes
                  .where((t) => t != 'transfer')
                  .map((t) => ButtonSegment(value: t, label: Text('transactions.type.$t'.tr())))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Text('accounts.error'.tr()),
              data: (accounts) {
                final labelOf = {for (final a in accounts) a.id: a.name};
                return AppSelectField(
                  label: 'transactions.account'.tr(),
                  valueLabel: _accountId == null ? null : labelOf[_accountId],
                  onTap: () async {
                    final picked = await showAppOptionSheet<int>(
                      context: context,
                      title: 'transactions.account'.tr(),
                      options: accounts.map((a) => a.id).toList(),
                      labelOf: (id) => labelOf[id]!,
                      selected: _accountId,
                    );
                    setState(() => _accountId = picked);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (categories) {
                final filtered = categories.where((c) => c.kind == _type).toList();
                final validCategoryId = filtered.any((c) => c.id == _categoryId) ? _categoryId : null;
                final labelOf = {for (final c in filtered) c.id: c.name.tr()};
                return AppSelectField(
                  label: 'transactions.category'.tr(),
                  valueLabel: validCategoryId == null
                      ? null
                      : labelOf[validCategoryId],
                  placeholder: 'goals.no_linked_account'.tr(),
                  onTap: () async {
                    final options = <int?>[null, ...filtered.map((c) => c.id)];
                    final picked = await showAppOptionSheet<int?>(
                      context: context,
                      title: 'transactions.category'.tr(),
                      options: options,
                      labelOf: (id) =>
                          id == null ? 'goals.no_linked_account'.tr() : labelOf[id]!,
                      selected: validCategoryId,
                    );
                    setState(() => _categoryId = picked);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _amountController,
              label: 'transactions.amount'.tr(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'common.required'.tr();
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'common.invalid_number'.tr();
                return parsed <= 0 ? 'transactions.amount_positive'.tr() : null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _dayController,
              label: 'recurring.day_of_month'.tr(),
              keyboardType: TextInputType.number,
              validator: (v) {
                final parsed = int.tryParse(v?.trim() ?? '');
                if (parsed == null) return 'common.invalid_number'.tr();
                return (parsed < 1 || parsed > 28) ? 'common.invalid_number'.tr() : null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
  }
}
