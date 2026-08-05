import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
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
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _categoryId == null || _accountId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('transactions.quick_add_invalid'.tr())));
      return;
    }
    final note = _noteController.text.trim();
    final categoryId = _categoryId;

    setState(() => _saving = true);
    try {
      await ref.read(transactionsNotifierProvider).add(
            type: 'expense',
            amount: amount,
            date: DateTime.now(),
            accountId: _accountId!,
            categoryId: categoryId,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      await checkAndNotifyOverspend(ref.read(databaseProvider), categoryId, DateTime.now());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            Text('transactions.quick_add_title'.tr(), style: AppTextStyles.body),
            const SizedBox(height: 12),
            AppTextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              label: 'transactions.amount'.tr(),
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
                  runSpacing: 8,
                  children: [
                    for (final category in ordered)
                      GestureDetector(
                        onTap: () => setState(() => _categoryId = category.id),
                        child: _categoryId == category.id
                            ? CategoryBadge(label: category.name.tr())
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSunken,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  category.name.tr(),
                                  style: AppTextStyles.caption,
                                ),
                              ),
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
                if (accounts.length <= 1) return const SizedBox.shrink();
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
            const SizedBox(height: 12),
            AppTextField(
              controller: _noteController,
              label: 'transactions.note'.tr(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _saving ? null : _save, child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
  }
}
