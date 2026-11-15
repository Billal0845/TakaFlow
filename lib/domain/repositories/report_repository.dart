import '../../core/money/money.dart';

class CategorySpending {
  final String categoryId;
  final String categoryNameEn;
  final String? categoryNameBn;
  final String? color;
  final String? icon;
  final int spentMinor;
  final double percentage;

  CategorySpending({
    required this.categoryId,
    required this.categoryNameEn,
    this.categoryNameBn,
    this.color,
    this.icon,
    required this.spentMinor,
    required this.percentage,
  });

  Money get money => Money.fromMinor(spentMinor);
}

class DailyTrendPoint {
  final String localDate;
  final int expenseMinor;
  final int incomeMinor;

  DailyTrendPoint({
    required this.localDate,
    required this.expenseMinor,
    required this.incomeMinor,
  });
}

class PeriodReportSummary {
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netSavingsMinor;
  final int transactionCount;
  final int avgDailyExpenseMinor;
  final List<CategorySpending> categoryBreakdown;
  final List<DailyTrendPoint> trend;

  PeriodReportSummary({
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netSavingsMinor,
    required this.transactionCount,
    required this.avgDailyExpenseMinor,
    required this.categoryBreakdown,
    required this.trend,
  });

  Money get totalIncome => Money.fromMinor(totalIncomeMinor);
  Money get totalExpense => Money.fromMinor(totalExpenseMinor);
  Money get netSavings => Money.fromMinor(netSavingsMinor);
  Money get avgDailyExpense => Money.fromMinor(avgDailyExpenseMinor);
}

abstract class ReportRepository {
  Future<PeriodReportSummary> getReportForDateRange({
    required String fromDate,
    required String toDate,
  });
}
