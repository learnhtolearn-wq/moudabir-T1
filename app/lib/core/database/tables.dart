import 'package:drift/drift.dart';

/// Account types: cash wallet, bank account, savings account, credit card, loan/debt.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()(); // cash | bank | savings | credit_card | loan
  TextColumn get currency => text().withDefault(const Constant('MAD'))();
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconName => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Categories cover both expense/income buckets and loan/debt tracking (Epic 2).
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get kind => text()(); // income | expense | debt | loan
  IntColumn get parentId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconName => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Single source of truth for income, expense, and transfer movements.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // income | expense | transfer
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  @ReferenceName('sourceTransactions')
  IntColumn get accountId =>
      integer().references(Accounts, #id)();
  // Only set for transfers: the destination account.
  @ReferenceName('destinationTransactions')
  IntColumn get toAccountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Savings goals (Epic 7): target amount, deadline, linked account for contributions.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  IntColumn get linkedAccountId =>
      integer().nullable().references(Accounts, #id)();
  BoolColumn get achieved => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
