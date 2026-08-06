import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('accounts.title'.tr())),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('accounts.error'.tr())),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(child: Text('accounts.empty'.tr()));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              return AppListItem(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.orTint,
                  child: Text(
                    account.name[0].toUpperCase(),
                    style: AppTextStyles.body.copyWith(color: AppColors.or),
                  ),
                ),
                title: account.name,
                subtitle: 'accounts.type.${account.type}'.tr(),
                trailing: Text(formatted, style: AppTextStyles.amount),
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
      floatingActionButton: accountsAsync.maybeWhen(
        data: (accounts) => accounts.isEmpty
            ? FloatingActionButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountsFormScreen()),
                ),
                child: const Icon(Icons.add),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}
