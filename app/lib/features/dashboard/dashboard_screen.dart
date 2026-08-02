import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ],
      ),
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
