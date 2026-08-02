import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
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
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'goals.contribute_amount'.tr()),
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
      appBar: AppBar(title: Text('goals.title'.tr())),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('goals.error'.tr())),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(child: Text('goals.empty'.tr()));
          }
          return ListView.builder(
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
              return ListTile(
                leading: Icon(
                  goal.achieved ? Icons.emoji_events : Icons.savings_outlined,
                ),
                title: Text(goal.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text(
                        '${formatted.format(goal.currentAmount)} / '
                        '${formatted.format(goal.targetAmount)}',
                      ),
                    ],
                  ),
                ),
                trailing: goal.achieved
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _contribute(context, ref, goal),
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GoalsFormScreen(goal: goal),
                  ),
                ),
              );
            },
          );
        },
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
