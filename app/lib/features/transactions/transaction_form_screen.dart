import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../accounts/providers/accounts_provider.dart';
import '../categories/providers/categories_provider.dart';
import 'providers/transactions_provider.dart';

const transactionTypes = ['income', 'expense', 'transfer'];

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final Transaction? transaction;

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
    _type = t?.type ?? transactionTypes.first;
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
          padding: const EdgeInsets.all(16),
          children: [
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
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Text('accounts.error'.tr()),
              data: (accounts) => DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: _type == 'transfer'
                      ? 'transactions.from_account'.tr()
                      : 'transactions.account'.tr(),
                ),
                items: accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'common.required'.tr() : null,
              ),
            ),
            if (_type == 'transfer') ...[
              const SizedBox(height: 16),
              accountsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (accounts) => DropdownButtonFormField<int>(
                  initialValue: _toAccountId,
                  decoration:
                      InputDecoration(labelText: 'transactions.to_account'.tr()),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _toAccountId = v;
                    _transferError = null;
                  }),
                  validator: (v) => v == null ? 'common.required'.tr() : null,
                ),
              ),
              if (_transferError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _transferError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) {
                  final filtered =
                      categories.where((c) => c.kind == _type).toList();
                  return DropdownButtonFormField<int>(
                    initialValue: filtered.any((c) => c.id == _categoryId)
                        ? _categoryId
                        : null,
                    decoration:
                        InputDecoration(labelText: 'transactions.category'.tr()),
                    items: filtered
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name.tr())))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'common.required'.tr() : null,
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'transactions.amount'.tr()),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('transactions.date'.tr()),
              subtitle: Text(DateFormat.yMMMd(context.locale.toString()).format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: 'transactions.note'.tr()),
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
