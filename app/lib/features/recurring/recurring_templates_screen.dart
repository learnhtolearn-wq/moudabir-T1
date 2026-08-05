import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'providers/recurring_provider.dart';
import 'recurring_form_screen.dart';

class RecurringTemplatesScreen extends ConsumerWidget {
  const RecurringTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('recurring.title'.tr())),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('recurring.error'.tr())),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(child: Text('recurring.empty'.tr()));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return AppListItem(
                leading: AppIconAvatar(
                  icon: template.type == 'income'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
                title: template.name,
                subtitle: 'recurring.day_of_month_subtitle'
                    .tr(namedArgs: {'day': '${template.dayOfMonth}'}),
                trailing: Switch(
                  value: template.active,
                  onChanged: (v) =>
                      ref.read(recurringNotifierProvider).setActive(template.id, v),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecurringFormScreen(template: template),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
