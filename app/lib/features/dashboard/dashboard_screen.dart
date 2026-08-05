import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../transactions/quick_add_sheet.dart';
import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalBalanceProvider);
    final monthlyAsync = ref.watch(monthlySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ScreenHeader(title: 'nav.dashboard'.tr()),
            const SizedBox(height: 20),
            _StatCard(
              label: 'dashboard.total_balance'.tr(),
              value: totalAsync,
              color: AppColors.vault,
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'dashboard.month_income'.tr(),
              value: monthlyAsync.whenData((s) => s.income),
              color: AppColors.vault,
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'dashboard.month_expense'.tr(),
              value: monthlyAsync.whenData((s) => s.expense),
              color: Colors.red,
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
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
              style: AppTextStyles.amount.copyWith(color: color, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}
