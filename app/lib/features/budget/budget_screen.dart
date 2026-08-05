import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/settings/settings_prefs.dart';
import '../accounts/providers/accounts_provider.dart';
import '../categories/providers/categories_provider.dart';
import '../dashboard/providers/dashboard_provider.dart';
import 'providers/budget_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, bool> _sweepFlags = {};
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int categoryId, double initial) {
    return _controllers.putIfAbsent(
      categoryId,
      () => TextEditingController(text: initial > 0 ? initial.toString() : ''),
    );
  }

  Future<void> _saveAllocation(List<Category> expenseCategories) async {
    final targetByCategory = <int, double>{
      for (final c in expenseCategories)
        c.id: double.tryParse(_controllers[c.id]?.text.trim() ?? '') ?? 0,
    };
    await ref.read(budgetNotifierProvider).saveAllocation(
          targetByCategory: targetByCategory,
          sweepByCategory: _sweepFlags,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('budget.allocation_saved'.tr())));
    }
  }

  Future<int?> _pickAccount(List<Account> accounts, {required String title}) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...accounts.map(
              (a) => ListTile(title: Text(a.name), onTap: () => Navigator.pop(ctx, a.id)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sweepCategory(BudgetTargetWithCategory row, double leftover) async {
    final accounts = await ref.read(accountsProvider.future);
    var savingsAccountId = await SettingsPrefs.getDefaultSavingsAccountId();

    if (savingsAccountId == null || !accounts.any((a) => a.id == savingsAccountId)) {
      savingsAccountId =
          await _pickAccount(accounts, title: 'budget.pick_savings_account'.tr());
      if (savingsAccountId == null) return;
      await SettingsPrefs.setDefaultSavingsAccountId(savingsAccountId);
    }

    final fromCandidates = accounts.where((a) => a.id != savingsAccountId).toList();
    final fromAccountId =
        await _pickAccount(fromCandidates, title: 'budget.pick_source_account'.tr());
    if (fromAccountId == null) return;

    final categoryLabel = row.category.name.tr();
    await ref.read(budgetNotifierProvider).sweep(
          target: row.target,
          leftover: leftover,
          spentSoFar: row.target.targetAmount - leftover,
          fromAccountId: fromAccountId,
          toAccountId: savingsAccountId,
          note: 'budget.sweep_note'.tr(namedArgs: {'category': categoryLabel}),
        );
    await NotificationService.showOneShot(
      id: 3000 + row.target.id,
      title: 'notifications.sweep_done'.tr(
        namedArgs: {'category': categoryLabel, 'amount': leftover.toStringAsFixed(2)},
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('budget.sweep_success'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final targetsAsync = ref.watch(budgetTargetsProvider);
    final sweepEligibleAsync = ref.watch(sweepEligibleProvider);
    final monthlyAsync = ref.watch(monthlySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('budget.title'.tr())),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('budget.error'.tr())),
        data: (categories) {
          final expenseCategories = categories.where((c) => c.kind == 'expense').toList();

          return targetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text('budget.error'.tr())),
            data: (targets) {
              if (!_initialized) {
                for (final row in targets) {
                  _controllerFor(row.category.id, row.target.targetAmount);
                  _sweepFlags[row.category.id] = row.target.sweepToSavings;
                }
                _initialized = true;
              }

              final allocated = expenseCategories.fold<double>(
                0,
                (sum, c) => sum + (double.tryParse(_controllers[c.id]?.text ?? '') ?? 0),
              );
              final income = monthlyAsync.asData?.value.income ?? 0;
              final remaining = income - allocated;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('budget.allocate_header'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('budget.remaining_to_allocate'
                      .tr(namedArgs: {'amount': remaining.toStringAsFixed(2)})),
                  const SizedBox(height: 12),
                  for (final category in expenseCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(category.name.tr())),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _controllerFor(category.id, 0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration:
                                  InputDecoration(labelText: 'budget.target_amount'.tr()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          Checkbox(
                            value: _sweepFlags[category.id] ?? false,
                            onChanged: (v) =>
                                setState(() => _sweepFlags[category.id] = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  FilledButton(
                    onPressed: () => _saveAllocation(expenseCategories),
                    child: Text('budget.save_allocation'.tr()),
                  ),
                  const Divider(height: 32),
                  Text('budget.sweep_header'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  sweepEligibleAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Text('budget.error'.tr()),
                    data: (rows) {
                      if (rows.isEmpty) return Text('budget.sweep_empty'.tr());
                      return Column(
                        children: [
                          for (final entry in rows)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.row.category.name.tr()),
                              subtitle: Text(
                                NumberFormat.currency(
                                  locale: context.locale.toString(),
                                  symbol: 'MAD ',
                                  decimalDigits: 2,
                                ).format(entry.leftover),
                              ),
                              trailing: FilledButton(
                                onPressed: () => _sweepCategory(entry.row, entry.leftover),
                                child: Text('budget.sweep_action'.tr()),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
