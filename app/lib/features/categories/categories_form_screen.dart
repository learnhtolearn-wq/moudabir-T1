import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import 'categories_screen.dart' show categoryKinds;
import 'providers/categories_provider.dart';

class CategoriesFormScreen extends ConsumerStatefulWidget {
  const CategoriesFormScreen({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<CategoriesFormScreen> createState() =>
      _CategoriesFormScreenState();
}

class _CategoriesFormScreenState extends ConsumerState<CategoriesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _kind;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _kind = widget.category?.kind ?? categoryKinds.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(categoriesNotifierProvider);
    final name = _nameController.text.trim();

    if (_isEditing) {
      await notifier.update(
        widget.category!.copyWith(name: name, kind: _kind),
      );
    } else {
      await notifier.add(name: name, kind: _kind);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('categories.archive_title'.tr()),
        content: Text('categories.archive_confirm'.tr()),
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
      await ref.read(categoriesNotifierProvider).archive(widget.category!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'categories.edit_title'.tr()
            : 'categories.add_title'.tr()),
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
              decoration: InputDecoration(labelText: 'categories.name'.tr()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'common.required'.tr() : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: 'categories.kind_label'.tr()),
              items: categoryKinds
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text('categories.kind.$k'.tr()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _kind = v!),
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
