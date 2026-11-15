import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/clock.dart';
import '../data/db/app_database.dart';
import '../data/db/seed_service.dart';
import '../data/repositories/drift_report_repository.dart';
import '../data/repositories/drift_transaction_repository.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../parsing/category_matcher.dart';
import '../parsing/rule_parser.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final seedServiceProvider = Provider<SeedService>((ref) {
  final db = ref.watch(databaseProvider);
  return SeedService(db);
});

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftTransactionRepository(db);
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftReportRepository(db);
});

final categoryMatcherProvider = FutureProvider<CategoryMatcher>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.categoryKeywords).get();
  final entries = rows.map((r) {
    return CategoryKeywordEntry(
      keyword: r.keyword,
      categoryId: r.categoryId,
      weight: r.weight,
    );
  }).toList();
  return CategoryMatcher(entries);
});

final ruleParserProvider = FutureProvider<RuleParser>((ref) async {
  final clock = ref.watch(clockProvider);
  final matcher = await ref.watch(categoryMatcherProvider.future);
  return RuleParser(clock: clock, categoryMatcher: matcher);
});

// App settings state (UI language, digit style)
class AppSettingsState {
  final String locale; // 'bn' or 'en'
  final bool useBanglaDigits;
  final String defaultCurrency;
  final String defaultAccountId;

  const AppSettingsState({
    this.locale = 'bn',
    this.useBanglaDigits = false,
    this.defaultCurrency = 'BDT',
    this.defaultAccountId = 'acc_cash',
  });

  AppSettingsState copyWith({
    String? locale,
    bool? useBanglaDigits,
    String? defaultCurrency,
    String? defaultAccountId,
  }) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      useBanglaDigits: useBanglaDigits ?? this.useBanglaDigits,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final AppDatabase db;

  AppSettingsNotifier(this.db) : super(const AppSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await db.select(db.appSettings).get();
    final map = {for (var s in settings) s.key: s.value};

    state = AppSettingsState(
      locale: map['ui_locale'] ?? 'bn',
      useBanglaDigits: map['digit_style'] == 'bn',
      defaultCurrency: map['default_currency'] ?? 'BDT',
      defaultAccountId: map['default_account'] ?? 'acc_cash',
    );
  }

  Future<void> setLocale(String langCode) async {
    state = state.copyWith(locale: langCode);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(
            key: 'ui_locale',
            value: langCode,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> setDigitStyle(bool useBangla) async {
    state = state.copyWith(useBanglaDigits: useBangla);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(
            key: 'digit_style',
            value: useBangla ? 'bn' : 'en',
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsNotifier(db);
});
