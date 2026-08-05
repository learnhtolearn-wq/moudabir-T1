import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../accounts/providers/accounts_provider.dart';
import '../budget/providers/budget_provider.dart';
import '../categories/providers/categories_provider.dart';
import 'providers/transactions_provider.dart';

const transactionTypes = ['income', 'expense', 'transfer'];

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction, this.initialType});

  final Transaction? transaction;

  /// Preselects the type when adding a new transaction (e.g. from a
  /// "+ Income" / "+ Expense" quick-add button). Ignored when editing.
  final String? initialType;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _type;
  late DateTime _date;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  String? _transferError;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController =
        TextEditingController(text: t != null ? t.amount.toString() : '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _type = t?.type ?? widget.initialType ?? transactionTypes.first;
    _date = t?.date ?? DateTime.now();
    _accountId = t?.accountId;
    _toAccountId = t?.toAccountId;
    _categoryId = t?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _transferError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    if (_type == 'transfer' && (_toAccountId == null || _toAccountId == _accountId)) {
      setState(() => _transferError = 'transactions.transfer_same_account'.tr());
      return;
    }

    final notifier = ref.read(transactionsNotifierProvider);
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();

    if (_isEditing) {
      await notifier.update(
        widget.transaction!.copyWith(
          amount: amount,
          date: _date,
          accountId: _accountId!,
          toAccountId: Value(_type == 'transfer' ? _toAccountId : null),
          categoryId: Value(_type == 'transfer' ? null : _categoryId),
          note: Value(note.isEmpty ? null : note),
        ),
      );
    } else {
      await notifier.add(
        type: _type,
        amount: amount,
        date: _date,
        accountId: _accountId!,
        toAccountId: _type == 'transfer' ? _toAccountId : null,
        categoryId: _type == 'transfer' ? null : _categoryId,
        note: note.isEmpty ? null : note,
      );
    }
    if (!mounted) return;
    if (_type == 'expense' && _categoryId != null) {
      await checkAndNotifyOverspend(ref.read(databaseProvider), _categoryId, _date);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('transactions.archive_title'.tr()),
        content: Text('transactions.archive_confirm'.tr()),
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
      await ref.read(transactionsNotifierProvider).archive(widget.transaction!.id);
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
        title: Text(_isEditing
            ? 'transactions.edit_title'.tr()
            : 'transactions.add_title'.tr()),
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
          padding: const EdgeInsets.all(20),
          children: [
            // Quick-add ("+ Revenu" / "+ Dépense") already commits to a type,
            // so re-showing the picker would look like it ignored the tap.
            // Only editing (type is fixed) and the generic add path show it.
            if (_isEditing || widget.initialType == null) ...[
              SegmentedButton<String>(
                segments: transactionTypes
                    .map((t) => ButtonSegment(
                          value: t,
                          label: Text('transactions.type.$t'.tr()),
                        ))
                    .toList(),
                selected: {_type},
                onSelectionChanged: _isEditing
                    ? null
                    : (selection) => setState(() {
                          _type = selection.first;
                          _categoryId = null;
                          _toAccountId = null;
                          _transferError = null;
                        }),
              ),
              const SizedBox(height: 16),
            ],
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Text('accounts.error'.tr()),
              data: (accounts) {
                final labelOf = {for (final a in accounts) a.id: a.name};
                return AppSelectField(
                  label: _type == 'transfer'
                      ? 'transactions.from_account'.tr()
                      : 'transactions.account'.tr(),
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
            if (_type == 'transfer') ...[
              const SizedBox(height: 16),
              accountsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (accounts) {
                  final labelOf = {for (final a in accounts) a.id: a.name};
                  return AppSelectField(
                    label: 'transactions.to_account'.tr(),
                    valueLabel: _toAccountId == null ? null : labelOf[_toAccountId],
                    errorText: _transferError,
                    onTap: () async {
                      final picked = await showAppOptionSheet<int>(
                        context: context,
                        title: 'transactions.to_account'.tr(),
                        options: accounts.map((a) => a.id).toList(),
                        labelOf: (id) => labelOf[id]!,
                        selected: _toAccountId,
                      );
                      setState(() {
                        _toAccountId = picked;
                        _transferError = null;
                      });
                    },
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) {
                  final filtered =
                      categories.where((c) => c.kind == _type).toList();
                  final validCategoryId =
                      filtered.any((c) => c.id == _categoryId) ? _categoryId : null;
                  final labelOf = {for (final c in filtered) c.id: c.name.tr()};
                  return AppSelectField(
                    label: 'transactions.category'.tr(),
                    valueLabel: validCategoryId == null ? null : labelOf[validCategoryId],
                    onTap: () async {
                      final picked = await showAppOptionSheet<int>(
                        context: context,
                        title: 'transactions.category'.tr(),
                        options: filtered.map((c) => c.id).toList(),
                        labelOf: (id) => labelOf[id]!,
                        selected: validCategoryId,
                      );
                      setState(() => _categoryId = picked);
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _amountController,
              label: 'transactions.amount'.tr(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'common.required'.tr();
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'common.invalid_number'.tr();
                if (parsed <= 0) return 'transactions.amount_positive'.tr();
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppSelectField(
              label: 'transactions.date'.tr(),
              valueLabel: DateFormat.yMMMd(context.locale.toString()).format(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _noteController,
              label: 'transactions.note'.tr(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
