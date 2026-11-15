import 'package:drift/drift.dart';

import '../../domain/repositories/report_repository.dart';
import '../db/app_database.dart';

class DriftReportRepository implements ReportRepository {
  final AppDatabase db;

  DriftReportRepository(this.db);

  @override
  Future<PeriodReportSummary> getReportForDateRange({
    required String fromDate,
    required String toDate,
  }) async {
    // 1. Fetch non-deleted transactions in date range
    final txs = await (db.select(db.transactions)
          ..where((tbl) =>
              tbl.deletedAt.isNull() &
              tbl.localDate.isBetweenValues(fromDate, toDate))
          ..orderBy([(t) => OrderingTerm.asc(t.localDate)]))
        .get();

    int totalIncome = 0;
    int totalExpense = 0;
    int txCount = txs.length;

    // Track daily trend
    final Map<String, int> dailyExpenseMap = {};
    final Map<String, int> dailyIncomeMap = {};

    // Track category spend: cat_id -> spentMinor
    final Map<String, int> catSpendMap = {};

    for (final tx in txs) {
      final date = tx.localDate;
      dailyExpenseMap.putIfAbsent(date, () => 0);
      dailyIncomeMap.putIfAbsent(date, () => 0);

      if (tx.type == 'income') {
        totalIncome += tx.amountMinor;
        dailyIncomeMap[date] = dailyIncomeMap[date]! + tx.amountMinor;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amountMinor;
        dailyExpenseMap[date] = dailyExpenseMap[date]! + tx.amountMinor;

        final catId = tx.categoryId ?? 'cat_uncategorized';
        catSpendMap[catId] = (catSpendMap[catId] ?? 0) + tx.amountMinor;
      } else if (tx.type == 'refund') {
        // Refund reduces expense (Section 10.1)
        totalExpense -= tx.amountMinor;
        dailyExpenseMap[date] = dailyExpenseMap[date]! - tx.amountMinor;

        final catId = tx.categoryId ?? 'cat_uncategorized';
        catSpendMap[catId] = (catSpendMap[catId] ?? 0) - tx.amountMinor;
      }
    }

    if (totalExpense < 0) totalExpense = 0;

    // 2. Fetch categories to roll up to parent category
    final allCats = await db.select(db.categories).get();
    final catById = {for (var c in allCats) c.id: c};

    final Map<String, int> parentSpendMap = {};
    for (final entry in catSpendMap.entries) {
      final cat = catById[entry.key];
      // If has parent, roll up to parent
      final parentId = cat?.parentId ?? cat?.id ?? 'cat_uncategorized';
      parentSpendMap[parentId] = (parentSpendMap[parentId] ?? 0) + entry.value;
    }

    // Build category breakdown list
    final List<CategorySpending> breakdown = [];
    for (final entry in parentSpendMap.entries) {
      if (entry.value <= 0) continue;
      final cat = catById[entry.key];
      final pct = totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0.0;
      breakdown.add(CategorySpending(
        categoryId: entry.key,
        categoryNameEn: cat?.nameEn ?? 'Uncategorized',
        categoryNameBn: cat?.nameBn ?? 'বিবিধ',
        color: cat?.color ?? '#94A3B8',
        icon: cat?.icon ?? 'category',
        spentMinor: entry.value,
        percentage: pct,
      ));
    }

    breakdown.sort((a, b) => b.spentMinor.compareTo(a.spentMinor));

    // Daily trend points
    final allDates = {...dailyExpenseMap.keys, ...dailyIncomeMap.keys}.toList()..sort();
    final List<DailyTrendPoint> trend = allDates.map((d) {
      return DailyTrendPoint(
        localDate: d,
        expenseMinor: dailyExpenseMap[d] ?? 0,
        incomeMinor: dailyIncomeMap[d] ?? 0,
      );
    }).toList();

    // Average daily expense
    final daysCount = allDates.isEmpty ? 1 : allDates.length;
    final avgDaily = totalExpense ~/ daysCount;

    return PeriodReportSummary(
      totalIncomeMinor: totalIncome,
      totalExpenseMinor: totalExpense,
      netSavingsMinor: totalIncome - totalExpense,
      transactionCount: txCount,
      avgDailyExpenseMinor: avgDaily,
      categoryBreakdown: breakdown,
      trend: trend,
    );
  }
}
