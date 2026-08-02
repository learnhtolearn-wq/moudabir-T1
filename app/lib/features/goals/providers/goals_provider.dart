import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

final goalsProvider = StreamProvider.autoDispose<List<Goal>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.goals)
        ..where((g) => g.archived.equals(false))
        ..orderBy([(g) => OrderingTerm.asc(g.name)]))
      .watch();
});

final goalsNotifierProvider = Provider.autoDispose<GoalsNotifier>((ref) {
  return GoalsNotifier(ref.watch(databaseProvider));
});

class GoalsNotifier {
  GoalsNotifier(this._db);

  final AppDatabase _db;

  Future<void> add({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    int? linkedAccountId,
  }) {
    return _db.into(_db.goals).insert(
          GoalsCompanion.insert(
            name: name,
            targetAmount: targetAmount,
            deadline: Value(deadline),
            linkedAccountId: Value(linkedAccountId),
          ),
        );
  }

  Future<void> update(Goal goal) {
    return _db.update(_db.goals).replace(goal);
  }

  Future<void> archive(int id) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(id)))
        .write(const GoalsCompanion(archived: Value(true)));
  }

  /// Adds [amount] to the goal's saved progress, flipping [Goal.achieved]
  /// once the running total reaches the target.
  Future<void> contribute(Goal goal, double amount) {
    final newAmount = goal.currentAmount + amount;
    return (_db.update(_db.goals)..where((g) => g.id.equals(goal.id))).write(
      GoalsCompanion(
        currentAmount: Value(newAmount),
        achieved: Value(newAmount >= goal.targetAmount),
      ),
    );
  }
}
