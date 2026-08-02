import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transactions_provider.dart';

/// One slice of the expense-by-category breakdown.
class CategoryBreakdownSlice {
  CategoryBreakdownSlice({
    required this.categoryName,
    required this.total,
    required this.color,
  });

  final String categoryName;
  final double total;
  final Color color;
}

/// One month's income/expense totals, for the trend bar chart.
class MonthlyTotals {
  MonthlyTotals({required this.month, required this.income, required this.expense});

  final DateTime month;
  final double income;
  final double expense;
}

/// Palette used when a category has no `colorHex` set.
const _fallbackPalette = [
  Color(0xFF1F6F5C),
  Color(0xFFE07A5F),
  Color(0xFF3D5A80),
  Color(0xFFF2CC8F),
  Color(0xFF81B29A),
  Color(0xFF9B5DE5),
];

Color _parseColor(String? hex, int fallbackIndex) {
  if (hex == null || hex.isEmpty) {
    return _fallbackPalette[fallbackIndex % _fallbackPalette.length];
  }
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return value != null
      ? Color(value)
      : _fallbackPalette[fallbackIndex % _fallbackPalette.length];
}

/// Expense total per category for the current calendar month.
final categoryBreakdownProvider =
    Provider.autoDispose<AsyncValue<List<CategoryBreakdownSlice>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (rows) {
      final now = DateTime.now();
      final totals = <String, double>{};
      final colors = <String, String?>{};
      for (final row in rows) {
        if (row.account.archived) continue;
        final t = row.transaction;
        if (t.type != 'expense') continue;
        if (t.date.year != now.year || t.date.month != now.month) continue;
        final name = row.category?.name ?? '—';
        totals[name] = (totals[name] ?? 0) + t.amount;
        colors[name] = row.category?.colorHex;
      }
      final names = totals.keys.toList()
        ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
      final slices = <CategoryBreakdownSlice>[
        for (var i = 0; i < names.length; i++)
          CategoryBreakdownSlice(
            categoryName: names[i],
            total: totals[names[i]]!,
            color: _parseColor(colors[names[i]], i),
          ),
      ];
      return AsyncValue.data(slices);
    },
  );
});

/// Income vs expense totals for each of the last 6 calendar months
/// (oldest first), for the trend bar chart.
final monthlyTrendProvider =
    Provider.autoDispose<AsyncValue<List<MonthlyTotals>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (rows) {
      final now = DateTime.now();
      final months = [
        for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
      ];
      final income = {for (final m in months) m: 0.0};
      final expense = {for (final m in months) m: 0.0};

      for (final row in rows) {
        if (row.account.archived) continue;
        final t = row.transaction;
        if (t.type != 'income' && t.type != 'expense') continue;
        final key = DateTime(t.date.year, t.date.month);
        if (!income.containsKey(key)) continue;
        if (t.type == 'income') income[key] = income[key]! + t.amount;
        if (t.type == 'expense') expense[key] = expense[key]! + t.amount;
      }

      return AsyncValue.data([
        for (final m in months)
          MonthlyTotals(month: m, income: income[m]!, expense: expense[m]!),
      ]);
    },
  );
});
