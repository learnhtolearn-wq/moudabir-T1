import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final trendAsync = ref.watch(monthlyTrendProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ScreenHeader(title: 'nav.reports'.tr()),
          const SizedBox(height: 20),
          Text(
            'reports.category_breakdown_title'.tr(),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          breakdownAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('reports.error'.tr()),
            data: (slices) => slices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('reports.no_expenses'.tr())),
                  )
                : _CategoryBreakdownChart(slices: slices),
          ),
          const SizedBox(height: 32),
          Text(
            'reports.trend_title'.tr(),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          trendAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('reports.error'.tr()),
            data: (months) => _MonthlyTrendChart(months: months),
          ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownChart extends StatelessWidget {
  const _CategoryBreakdownChart({required this.slices});

  final List<CategoryBreakdownSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.total);
    final formatted = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: 'MAD',
      decimalDigits: 0,
    );

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    value: slice.total,
                    color: slice.color,
                    title: total <= 0
                        ? ''
                        : '${(slice.total / total * 100).round()}%',
                    radius: 60,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final slice in slices)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${slice.categoryName.tr()} · ${formatted.format(slice.total)}'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.months});

  final List<MonthlyTotals> months;

  @override
  Widget build(BuildContext context) {
    final maxY = months.fold<double>(
      0,
      (max, m) => [max, m.income, m.expense].reduce((a, b) => a > b ? a : b),
    );

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => const Color(0xFF2B2B2B),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      rod.toY.toStringAsFixed(2),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: months[i].income,
                        color: AppColors.or,
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: months[i].expense,
                        color: AppColors.corail,
                        width: 8,
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat.MMM(context.locale.languageCode)
                              .format(months[index].month),
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.or, label: 'reports.income'.tr()),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.corail, label: 'reports.expense'.tr()),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
