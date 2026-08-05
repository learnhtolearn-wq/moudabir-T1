import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import 'providers/transaction_filter_provider.dart';
import 'providers/transactions_provider.dart';
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

  void _openForm({String? initialType, Transaction? transaction}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          transaction: transaction,
          initialType: initialType,
        ),
      ),
    );
  }

  /// "Aujourd'hui" / "Hier" / a localized date, used as sticky section
  /// headers so the list reads as a day-by-day ledger, matching the design.
  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'transactions.section_today'.tr();
    if (day == today.subtract(const Duration(days: 1))) {
      return 'transactions.section_yesterday'.tr();
    }
    return DateFormat.yMMMd(context.locale.toString()).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final notifier = ref.read(transactionFilterProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('nav.transactions'.tr(), style: AppTextStyles.display),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.vaultTint,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/branding/icon_mark.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openForm(initialType: 'income'),
                      child:
                          Text('transactions.quick_add_income'.tr()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openForm(initialType: 'expense'),
                      child:
                          Text('transactions.quick_add_expense'.tr()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'transactions.filter_transfer'.tr(),
                    onPressed: () => _openForm(initialType: 'transfer'),
                    icon: const Icon(Icons.swap_horiz),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.bodyRegular,
                decoration: InputDecoration(
                  hintText: 'transactions.search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: notifier.setSearch,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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

                  // Group consecutive rows sharing a day label under one
                  // header, matching the design's "Aujourd'hui" / "Hier" split.
                  final items = <Widget>[];
                  String? lastLabel;
                  for (final row in rows) {
                    final label = _dayLabel(row.transaction.date);
                    if (label != lastLabel) {
                      items.add(Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, lastLabel == null ? 0 : 18, 20, 8),
                        child: Text(label, style: AppTextStyles.bodySmall),
                      ));
                      lastLabel = label;
                    }
                    items.add(Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _TransactionCard(
                        row: row,
                        onTap: () => _openForm(transaction: row.transaction),
                      ),
                    ));
                  }

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: items,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.row, required this.onTap});

  final TransactionWithDetails row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = row.transaction;
    final isIncome = t.type == 'income';
    final isTransfer = t.type == 'transfer';
    final sign = isIncome ? '+ ' : (isTransfer ? '' : '− ');
    final amountColor = isIncome ? AppColors.vault : AppColors.ink;
    final formatted = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: row.account.currency,
      decimalDigits: 2,
    ).format(t.amount.abs());
    final title = isTransfer
        ? '${row.account.name} → ${row.toAccount?.name ?? ''}'
        : (row.category?.name.tr() ?? row.account.name);
    final subtitle = isTransfer
        ? row.category?.name.tr() ?? ''
        : '${row.category?.name.tr() ?? ''} · ${row.account.name}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.vaultTint,
                child: Icon(
                  isIncome
                      ? Icons.arrow_upward
                      : (isTransfer
                          ? Icons.swap_horiz
                          : Icons.arrow_downward),
                  color: AppColors.vault,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.body),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Text(
                '$sign$formatted',
                style: AppTextStyles.amount.copyWith(color: amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
