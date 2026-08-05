import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../accounts/providers/accounts_provider.dart';
import '../budget/providers/budget_provider.dart';
import '../categories/providers/categories_provider.dart';
import 'providers/transactions_provider.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _categoryId;
  int? _accountId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _categoryId == null || _accountId == null) {
      return;
    }
    final note = _noteController.text.trim();
    final categoryId = _categoryId;

    await ref.read(transactionsNotifierProvider).add(
          type: 'expense',
          amount: amount,
          date: DateTime.now(),
          accountId: _accountId!,
          categoryId: categoryId,
          note: note.isEmpty ? null : note,
        );
    await checkAndNotifyOverspend(ref.read(databaseProvider), categoryId, DateTime.now());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    final recentCategoryIds = <int>[];
    for (final row in transactionsAsync.asData?.value ?? const []) {
      final id = row.category?.id;
      if (id != null && !recentCategoryIds.contains(id)) recentCategoryIds.add(id);
      if (recentCategoryIds.length == 3) break;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('transactions.quick_add_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'transactions.amount'.tr()),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (categories) {
                final expenseCategories =
                    categories.where((c) => c.kind == 'expense').toList();
                final pinned = [
                  for (final id in recentCategoryIds)
                    ...expenseCategories.where((c) => c.id == id),
                ];
                final rest =
                    expenseCategories.where((c) => !recentCategoryIds.contains(c.id));
                final ordered = [...pinned, ...rest];

                return Wrap(
                  spacing: 8,
                  children: [
                    for (final category in ordered)
                      ChoiceChip(
                        label: Text(category.name.tr()),
                        selected: _categoryId == category.id,
                        onSelected: (_) => setState(() => _categoryId = category.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) {
                _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
                return DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  decoration: InputDecoration(labelText: 'transactions.account'.tr()),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: 'transactions.note'.tr()),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
  }
}
