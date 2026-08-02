import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/accounts_provider.dart';
import '../../transactions/providers/transactions_provider.dart';

/// Income/expense totals for the current calendar month.
typedef MonthlySummary = ({double income, double expense});

/// Sum of all non-archived accounts' balances. Transfers between the
/// user's own accounts net to zero when summed across every account, so
/// the total is just starting balances plus total income minus total
/// expense — no need to combine per-account balance streams.
final totalBalanceProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  final transactionsAsync = ref.watch(transactionsProvider);

  return accountsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (accounts) => transactionsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, s) => AsyncValue.error(e, s),
      data: (rows) {
        var total = accounts.fold<double>(
          0,
          (sum, a) => sum + a.initialBalance,
        );
        for (final row in rows) {
          if (row.account.archived) continue;
          final t = row.transaction;
          if (t.type == 'income') total += t.amount;
          if (t.type == 'expense') total -= t.amount;
        }
        return AsyncValue.data(total);
      },
    ),
  );
});

/// This-month income/expense totals. Transfers are excluded — they move
/// money between the user's own accounts, not new income or spend.
final monthlySummaryProvider =
    Provider.autoDispose<AsyncValue<MonthlySummary>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (rows) {
      final now = DateTime.now();
      var income = 0.0;
      var expense = 0.0;
      for (final row in rows) {
        if (row.account.archived) continue;
        final t = row.transaction;
        if (t.date.year != now.year || t.date.month != now.month) continue;
        if (t.type == 'income') income += t.amount;
        if (t.type == 'expense') expense += t.amount;
      }
      return AsyncValue.data((income: income, expense: expense));
    },
  );
});
