import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/transaction_filter_provider.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(TransactionFilter filter) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: filter.dateRange,
    );
    if (picked != null) {
      ref.read(transactionFilterProvider.notifier).setDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final notifier = ref.read(transactionFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'transactions.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: notifier.setSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text('transactions.filter_all'.tr()),
                  selected: filter.type == null,
                  onSelected: (_) => notifier.setType(null),
                ),
                ChoiceChip(
                  label: Text('transactions.filter_income'.tr()),
                  selected: filter.type == 'income',
                  onSelected: (_) => notifier.setType('income'),
                ),
                ChoiceChip(
                  label: Text('transactions.filter_expense'.tr()),
                  selected: filter.type == 'expense',
                  onSelected: (_) => notifier.setType('expense'),
                ),
                ChoiceChip(
                  label: Text('transactions.filter_transfer'.tr()),
                  selected: filter.type == 'transfer',
                  onSelected: (_) => notifier.setType('transfer'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    filter.dateRange == null
                        ? 'transactions.filter_date_range'.tr()
                        : '${DateFormat.yMd(context.locale.toString()).format(filter.dateRange!.start)} '
                            '– '
                            '${DateFormat.yMd(context.locale.toString()).format(filter.dateRange!.end)}',
                  ),
                  onPressed: () => _pickDateRange(filter),
                ),
                if (filter.dateRange != null)
                  ActionChip(
                    avatar: const Icon(Icons.close, size: 18),
                    label: Text('transactions.filter_clear'.tr()),
                    onPressed: () => notifier.setDateRange(null),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('transactions.error'.tr())),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      filter.isActive
                          ? 'transactions.no_matches'.tr()
                          : 'transactions.empty'.tr(),
                    ),
                  );
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
                        : (isTransfer
                            ? Icons.swap_horiz
                            : Icons.arrow_downward);
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
                      subtitle: Text(
                        DateFormat.yMMMd(context.locale.toString())
                            .format(t.date),
                      ),
                      trailing: Text(
                        '$sign$formatted',
                        style: TextStyle(color: color),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              TransactionFormScreen(transaction: t),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
