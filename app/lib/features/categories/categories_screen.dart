import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'categories_form_screen.dart';
import 'providers/categories_provider.dart';

const categoryKinds = ['income', 'expense', 'debt', 'loan'];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('categories.title'.tr())),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('categories.error'.tr())),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(child: Text('categories.empty'.tr()));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(category.name.tr()),
                subtitle: Text('categories.kind.${category.kind}'.tr()),
                trailing: category.isSystem
                    ? Chip(label: Text('categories.system'.tr()))
                    : null,
                onTap: category.isSystem
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoriesFormScreen(category: category),
                          ),
                        ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoriesFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
