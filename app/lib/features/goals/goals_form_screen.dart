import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../accounts/providers/accounts_provider.dart';
import 'providers/goals_provider.dart';

class GoalsFormScreen extends ConsumerStatefulWidget {
  const GoalsFormScreen({super.key, this.goal});

  final Goal? goal;

  @override
  ConsumerState<GoalsFormScreen> createState() => _GoalsFormScreenState();
}

class _GoalsFormScreenState extends ConsumerState<GoalsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  DateTime? _deadline;
  int? _linkedAccountId;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal != null ? goal.targetAmount.toString() : '',
    );
    _deadline = goal?.deadline;
    _linkedAccountId = goal?.linkedAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(goalsNotifierProvider);
    final name = _nameController.text.trim();
    final target = double.parse(_targetController.text.trim());

    if (_isEditing) {
      await notifier.update(
        widget.goal!.copyWith(
          name: name,
          targetAmount: target,
          deadline: Value(_deadline),
          linkedAccountId: Value(_linkedAccountId),
        ),
      );
    } else {
      await notifier.add(
        name: name,
        targetAmount: target,
        deadline: _deadline,
        linkedAccountId: _linkedAccountId,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('goals.archive_title'.tr()),
        content: Text('goals.archive_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(goalsNotifierProvider).archive(widget.goal!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'goals.edit_title'.tr() : 'goals.add_title'.tr()),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _archive,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'goals.name'.tr()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'common.required'.tr() : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetController,
              decoration: InputDecoration(labelText: 'goals.target_amount'.tr()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'common.required'.tr();
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'common.invalid_number'.tr();
                return parsed <= 0 ? 'goals.amount_positive'.tr() : null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('goals.deadline'.tr()),
              subtitle: Text(
                _deadline == null
                    ? 'goals.no_deadline'.tr()
                    : DateFormat.yMMMd().format(_deadline!),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) => DropdownButtonFormField<int?>(
                initialValue: _linkedAccountId,
                decoration: InputDecoration(labelText: 'goals.linked_account'.tr()),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('goals.no_linked_account'.tr()),
                  ),
                  ...accounts.map(
                    (a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _linkedAccountId = v),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
