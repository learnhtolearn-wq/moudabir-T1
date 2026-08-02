import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/transactions_provider.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('transactions.error'.tr())),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(child: Text('transactions.empty'.tr()));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final t = row.transaction;
              final isIncome = t.type == 'income';
              final isTransfer = t.type == 'transfer';
              final sign = isIncome ? '+' : (isTransfer ? '' : '-');
              final color = isIncome
                  ? Colors.green
                  : (isTransfer ? Colors.grey : Colors.red);
              final icon = isIncome
                  ? Icons.arrow_upward
                  : (isTransfer ? Icons.swap_horiz : Icons.arrow_downward);
              final formatted = NumberFormat.currency(
                symbol: row.account.currency,
                decimalDigits: 2,
              ).format(t.amount);
              final subtitle = isTransfer
                  ? '${row.account.name} → ${row.toAccount?.name ?? ''}'
                  : '${row.account.name}'
                      '${row.category != null ? ' · ${row.category!.name}' : ''}';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                title: Text(subtitle),
                subtitle: Text(DateFormat.yMMMd(context.locale.toString()).format(t.date)),
                trailing: Text('$sign$formatted', style: TextStyle(color: color)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TransactionFormScreen(transaction: t),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
