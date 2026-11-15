import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    CategoryKeywords,
    Transactions,
    TransactionTags,
    TransactionAudit,
    PendingRecordings,
    Budgets,
    AppSettings,
    AiUsageLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(
          e ??
              driftDatabase(
                name: 'self_accountant',
                web: DriftWebOptions(
                  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                  driftWorker: Uri.parse('drift_worker.js'),
                ),
              ),
        );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create indexes as specified in Section 8.3
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tx_local_date ON transactions(local_date);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tx_deleted_local_date ON transactions(deleted_at, local_date);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tx_cat_local_date ON transactions(category_id, local_date);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tx_acc_local_date ON transactions(account_id, local_date);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tx_dedup_hash ON transactions(dedup_hash);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_cat_keywords_kw ON category_keywords(keyword);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_pending_status_attempt ON pending_recordings(status, next_attempt_at);',
        );
      },
    );
  }
}
