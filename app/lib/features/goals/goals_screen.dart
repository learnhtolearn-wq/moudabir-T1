import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'goals_form_screen.dart';
import 'providers/goals_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('goals.contribute_title'.tr()),
        content: AppTextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          label: 'goals.contribute_amount'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      await ref.read(goalsNotifierProvider).contribute(goal, amount);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: ScreenHeader(title: 'goals.title'.tr()),
            ),
            Expanded(
              child: goalsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('goals.error'.tr())),
                data: (goals) {
                  if (goals.isEmpty) {
                    return Center(child: Text('goals.empty'.tr()));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: goals.length,
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      final progress = goal.targetAmount <= 0
                          ? 0.0
                          : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
                      final formatted = NumberFormat.currency(
                        locale: context.locale.toString(),
                        symbol: 'MAD',
                        decimalDigits: 2,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GoalsFormScreen(goal: goal),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppIconAvatar(
                                    icon: goal.achieved
                                        ? Icons.emoji_events
                                        : Icons.savings_outlined,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(goal.name, style: AppTextStyles.body),
                                        const SizedBox(height: 8),
                                        ProgressGauge(value: progress),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${formatted.format(goal.currentAmount)} / '
                                          '${formatted.format(goal.targetAmount)}',
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!goal.achieved)
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      color: AppColors.vault,
                                      onPressed: () => _contribute(context, ref, goal),
                                    ),
                                ],
                              ),
                            ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalsFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
