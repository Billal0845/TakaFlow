import 'package:drift/drift.dart';

@DataClassName('AccountEntry')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // cash, bkash, nagad, bank, card, other
  TextColumn get currency => text().withDefault(const Constant('BDT'))();
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get isDefault => integer().withDefault(const Constant(0))();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryEntry')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get nameBn => text().nullable()();
  TextColumn get nameEn => text()();
  TextColumn get kind => text()(); // expense, income, both
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get isSystem => integer().withDefault(const Constant(0))();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryKeywordEntryData')
class CategoryKeywords extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get keyword => text()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();
  TextColumn get source => text()(); // seed, user, llm
  IntColumn get hits => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionEntry')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // expense, income, transfer, refund, loan_given, loan_received, loan_repayment
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('BDT'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get itemTag => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()();
  TextColumn get counterparty => text().nullable()();
  IntColumn get occurredAt => integer()(); // UTC epoch ms
  TextColumn get localDate => text()(); // YYYY-MM-DD
  TextColumn get source => text()(); // voice, text, manual, import
  TextColumn get parseMethod => text().nullable()(); // rules, llm, manual
  RealColumn get confidence => real().nullable()();
  TextColumn get sourceText => text().nullable()();
  TextColumn get dedupHash => text()();
  TextColumn get recordingId => text().nullable()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionTagEntry')
class TransactionTags extends Table {
  TextColumn get transactionId => text()();
  TextColumn get tag => text()(); // recurring, one_time, essential, discretionary, emergency

  @override
  Set<Column> get primaryKey => {transactionId, tag};
}

@DataClassName('TransactionAuditEntry')
class TransactionAudit extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get action => text()(); // create, update, delete, restore
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  IntColumn get at => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingRecordingEntry')
class PendingRecordings extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // audio, text
  TextColumn get filePath => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get locale => text().nullable()();
  TextColumn get status => text()(); // queued, uploading, transcribed, parsed, failed, done
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get transcript => text().nullable()();
  TextColumn get draftJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BudgetEntry')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get period => text().withDefault(const Constant('monthly'))();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('BDT'))();
  TextColumn get startsOn => text()();
  TextColumn get endsOn => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSettingEntry')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('AiUsageLogEntry')
class AiUsageLog extends Table {
  TextColumn get id => text()();
  TextColumn get provider => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get purpose => text().nullable()();
  IntColumn get tokensIn => integer().nullable()();
  IntColumn get tokensOut => integer().nullable()();
  IntColumn get latencyMs => integer().nullable()();
  IntColumn get ok => integer().withDefault(const Constant(1))();
  IntColumn get at => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
