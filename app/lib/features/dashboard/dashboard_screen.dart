import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../budget/budget_screen.dart';
import '../budget/providers/budget_provider.dart';
import '../transactions/quick_add_sheet.dart';
import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalBalanceProvider);
    final monthlyAsync = ref.watch(monthlySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.dashboard'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AllocateBanner(),
          const SizedBox(height: 12),
          _StatCard(
            label: 'dashboard.total_balance'.tr(),
            value: totalAsync,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: 'dashboard.month_income'.tr(),
            value: monthlyAsync.whenData((s) => s.income),
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: 'dashboard.month_expense'.tr(),
            value: monthlyAsync.whenData((s) => s.expense),
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          const _BudgetProgressSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const QuickAddSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AllocateBanner extends ConsumerWidget {
  const _AllocateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyAsync = ref.watch(monthlySummaryProvider);
    final targetsAsync = ref.watch(budgetTargetsProvider);

    final hasIncome = (monthlyAsync.asData?.value.income ?? 0) > 0;
    final hasTargets = targetsAsync.asData?.value.isNotEmpty ?? true;
    if (!hasIncome || hasTargets) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        title: Text('dashboard.allocate_banner'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetScreen()),
        ),
      ),
    );
  }
}

class _BudgetProgressSection extends ConsumerWidget {
  const _BudgetProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(budgetTargetsProvider);

    return targetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (targets) {
        if (targets.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('dashboard.budget_progress_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in targets) _BudgetProgressRow(row: row),
          ],
        );
      },
    );
  }
}

class _BudgetProgressRow extends ConsumerWidget {
  const _BudgetProgressRow({required this.row});

  final BudgetTargetWithCategory row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync = ref.watch(categorySpentProvider(row.category.id));

    return spentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (spent) {
        final target = row.target.targetAmount;
        final ratio = target <= 0 ? 0.0 : (spent / target).clamp(0.0, 1.0);
        final color = ratio >= 1.0
            ? Colors.red
            : ratio >= 0.8
                ? Colors.orange
                : Colors.green;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.category.name.tr()),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: ratio, color: color),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final AsyncValue<double> value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            value.when(
              loading: () => const Text('…'),
              error: (_, _) => const Text('—'),
              data: (v) => Text(
                // Default-currency formatting — see "Known limitation" note
                // in the plan header re: multi-currency accounts.
                NumberFormat.currency(
                  locale: context.locale.toString(),
                  symbol: 'MAD ',
                  decimalDigits: 2,
                ).format(v),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
