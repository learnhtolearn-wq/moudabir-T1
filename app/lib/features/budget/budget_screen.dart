import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/settings/settings_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
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
  final Set<int> _sweepingTargetIds = {};
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
    if (_sweepingTargetIds.contains(row.target.id)) return;
    setState(() => _sweepingTargetIds.add(row.target.id));
    try {
      final accounts = await ref.read(accountsProvider.future);
      var savingsAccountId = await SettingsPrefs.getDefaultSavingsAccountId();

      if (savingsAccountId == null || !accounts.any((a) => a.id == savingsAccountId)) {
        if (accounts.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('budget.no_accounts_available'.tr())));
          }
          return;
        }
        savingsAccountId =
            await _pickAccount(accounts, title: 'budget.pick_savings_account'.tr());
        if (savingsAccountId == null) return;
        await SettingsPrefs.setDefaultSavingsAccountId(savingsAccountId);
      }

      final fromCandidates = accounts.where((a) => a.id != savingsAccountId).toList();
      if (fromCandidates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('budget.no_accounts_available'.tr())));
        }
        return;
      }
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
    } finally {
      if (mounted) setState(() => _sweepingTargetIds.remove(row.target.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final targetsAsync = ref.watch(budgetTargetsProvider);
    final sweepEligibleAsync = ref.watch(sweepEligibleProvider);
    final monthlyAsync = ref.watch(monthlySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                padding: const EdgeInsets.all(20),
                children: [
                  Text('budget.allocate_header'.tr(), style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Text(
                    'budget.remaining_to_allocate'
                        .tr(namedArgs: {'amount': remaining.toStringAsFixed(2)}),
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 12),
                  for (final category in expenseCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(category.name.tr(), style: AppTextStyles.bodyRegular),
                          ),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _controllerFor(category.id, 0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              label: 'budget.target_amount'.tr(),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          Checkbox(
                            value: _sweepFlags[category.id] ?? false,
                            activeColor: AppColors.or,
                            onChanged: (v) =>
                                setState(() => _sweepFlags[category.id] = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => _saveAllocation(expenseCategories),
                    child: Text('budget.save_allocation'.tr()),
                  ),
                  const SizedBox(height: 32),
                  Text('budget.sweep_header'.tr(), style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  sweepEligibleAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Text('budget.error'.tr()),
                    data: (rows) {
                      if (rows.isEmpty) return Text('budget.sweep_empty'.tr());
                      return Column(
                        children: [
                          for (final entry in rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppListItem(
                                leading: const AppIconAvatar(icon: Icons.savings_outlined),
                                title: entry.row.category.name.tr(),
                                subtitle: NumberFormat.currency(
                                  locale: context.locale.toString(),
                                  symbol: 'MAD ',
                                  decimalDigits: 2,
                                ).format(entry.leftover),
                                trailing: FilledButton(
                                  onPressed: _sweepingTargetIds.contains(entry.row.target.id)
                                      ? null
                                      : () => _sweepCategory(entry.row, entry.leftover),
                                  child: Text('budget.sweep_action'.tr()),
                                ),
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
