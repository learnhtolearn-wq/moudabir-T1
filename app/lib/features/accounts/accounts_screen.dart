import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transactions/providers/transactions_provider.dart';
import 'accounts_form_screen.dart';
import 'providers/accounts_provider.dart';

const accountTypes = ['cash', 'bank', 'savings', 'credit_card', 'loan'];

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('accounts.title'.tr())),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('accounts.error'.tr())),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(child: Text('accounts.empty'.tr()));
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              final balanceAsync = ref.watch(accountBalanceProvider(account.id));
              final formatted = balanceAsync.when(
                data: (balance) => NumberFormat.currency(
                  locale: context.locale.toString(),
                  symbol: account.currency,
                  decimalDigits: 2,
                ).format(balance),
                loading: () => '…',
                error: (_, _) => '—',
              );
              return ListTile(
                leading: CircleAvatar(child: Text(account.name[0].toUpperCase())),
                title: Text(account.name),
                subtitle: Text('accounts.type.${account.type}'.tr()),
                trailing: Text(formatted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountsFormScreen(account: account),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountsFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
