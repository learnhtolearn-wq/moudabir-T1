import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transactions_provider.dart';

/// Current search/filter criteria for the transactions list. `type: null`
/// means "all types"; `dateRange: null` means "all time".
class TransactionFilter {
  const TransactionFilter({
    this.searchText = '',
    this.type,
    this.dateRange,
  });

  final String searchText;
  final String? type;
  final DateTimeRange? dateRange;

  bool get isActive =>
      searchText.isNotEmpty || type != null || dateRange != null;

  TransactionFilter copyWith({
    String? searchText,
    String? type,
    bool clearType = false,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return TransactionFilter(
      searchText: searchText ?? this.searchText,
      type: clearType ? null : (type ?? this.type),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }
}

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(const TransactionFilter());

  void setSearch(String value) {
    state = state.copyWith(searchText: value);
  }

  void setType(String? value) {
    state = value == null
        ? state.copyWith(clearType: true)
        : state.copyWith(type: value);
  }

  void setDateRange(DateTimeRange? value) {
    state = value == null
        ? state.copyWith(clearDateRange: true)
        : state.copyWith(dateRange: value);
  }

  void clear() {
    state = const TransactionFilter();
  }
}

final transactionFilterProvider = StateNotifierProvider.autoDispose<
    TransactionFilterNotifier, TransactionFilter>(
  (ref) => TransactionFilterNotifier(),
);

/// `transactionsProvider`, narrowed by the current `TransactionFilter`.
/// Uses `AsyncValue.whenData` so loading/error states pass through
/// unchanged and only the data case gets filtered.
final filteredTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<TransactionWithDetails>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final filter = ref.watch(transactionFilterProvider);

  return transactionsAsync.whenData((rows) {
    return rows.where((row) {
      final t = row.transaction;

      if (filter.type != null && t.type != filter.type) return false;

      if (filter.dateRange != null) {
        final start = filter.dateRange!.start;
        final endExclusive =
            filter.dateRange!.end.add(const Duration(days: 1));
        if (t.date.isBefore(start) || !t.date.isBefore(endExclusive)) {
          return false;
        }
      }

      if (filter.searchText.isNotEmpty) {
        final q = filter.searchText.toLowerCase();
        final matchesAccount = row.account.name.toLowerCase().contains(q);
        final matchesToAccount =
            row.toAccount?.name.toLowerCase().contains(q) ?? false;
        final matchesCategory =
            row.category?.name.toLowerCase().contains(q) ?? false;
        final matchesNote = t.note?.toLowerCase().contains(q) ?? false;
        if (!(matchesAccount ||
            matchesToAccount ||
            matchesCategory ||
            matchesNote)) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});
