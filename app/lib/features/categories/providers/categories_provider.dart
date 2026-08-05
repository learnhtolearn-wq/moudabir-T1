import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

final categoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..where((c) => c.archived.equals(false))
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();
});

final categoriesNotifierProvider =
    Provider.autoDispose<CategoriesNotifier>((ref) {
  return CategoriesNotifier(ref.watch(databaseProvider));
});

class CategoriesNotifier {
  CategoriesNotifier(this._db);

  final AppDatabase _db;

  Future<bool> existsByName(String name, {int? excludeId}) async {
    final query = _db.select(_db.categories)
      ..where((c) => c.name.lower().equals(name.trim().toLowerCase()));
    if (excludeId != null) {
      query.where((c) => c.id.equals(excludeId).not());
    }
    final match = await query.getSingleOrNull();
    return match != null;
  }

  Future<void> add({
    required String name,
    required String kind,
    int? parentId,
    String? colorHex,
    String? iconName,
  }) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            parentId: Value(parentId),
            colorHex: Value(colorHex),
            iconName: Value(iconName),
          ),
        );
  }

  Future<void> update(Category category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<bool> hasTransactions(int categoryId) async {
    final match = await (_db.select(_db.transactions)
          ..where((t) => t.categoryId.equals(categoryId))
          ..limit(1))
        .getSingleOrNull();
    return match != null;
  }

  Future<void> archive(int id) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id)))
        .write(const CategoriesCompanion(archived: Value(true)));
  }
}
