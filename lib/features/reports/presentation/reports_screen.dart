import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../domain/repositories/report_repository.dart';
import '../application/csv_export_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedPeriodIndex = 2; // 0: Daily, 1: Weekly, 2: Monthly

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final strings = AppStrings(settings.locale);
    final reportRepo = ref.watch(reportRepositoryProvider);
    final clock = ref.watch(clockProvider);

    final now = clock.now();
    final todayStr = clock.todayLocalDate();

    // Compute fromDate & toDate
    String fromDate;
    final toDate = todayStr;

    if (_selectedPeriodIndex == 0) {
      // Daily
      fromDate = todayStr;
    } else if (_selectedPeriodIndex == 1) {
      // Weekly: last 7 days
      final weekAgo = now.subtract(const Duration(days: 7));
      fromDate = clock.toLocalDate(weekAgo);
    } else {
      // Monthly: start of current month
      final startOfMonth = DateTime(now.year, now.month, 1);
      fromDate = clock.toLocalDate(startOfMonth);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.reports),
        actions: [
          IconButton(
            tooltip: strings.exportCsv,
            icon: const Icon(Icons.download),
            onPressed: () async {
              final txRepo = ref.read(transactionRepositoryProvider);
              final allTxs = await txRepo.getTransactions();
              if (allTxs.isNotEmpty) {
                await CsvExportService.exportAndShare(allTxs);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.isBn ? 'রপ্তানি করার মতো কোনো লেনদেন নেই' : 'No transactions to export')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<PeriodReportSummary>(
        future: reportRepo.getReportForDateRange(fromDate: fromDate, toDate: toDate),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data;
          if (report == null) {
            return Center(
              child: Text(strings.isBn ? 'রিপোর্ট লোড করা যায়নি' : 'Failed to load report'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Period Selector
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Row(
                  children: [
                    _buildSegmentButton(0, strings.periodDaily),
                    _buildSegmentButton(1, strings.periodWeekly),
                    _buildSegmentButton(2, strings.periodMonthly),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      strings.totalExpense,
                      report.totalExpense.format(useBanglaDigits: settings.useBanglaDigits),
                      AppTheme.expenseRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      strings.totalIncome,
                      report.totalIncome.format(useBanglaDigits: settings.useBanglaDigits),
                      AppTheme.incomeGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Net Savings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.netSavings,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      Text(
                        report.netSavings.format(useBanglaDigits: settings.useBanglaDigits),
                        style: TextStyle(
                          color: report.netSavings.isNegative
                              ? AppTheme.expenseRed
                              : AppTheme.incomeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Category Breakdown Section
              Text(
                strings.categoryBreakdown,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (report.categoryBreakdown.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        strings.isBn ? 'এই সময়ের মধ্যে কোনো খরচ নেই' : 'No expense in this period',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                )
              else
                ...report.categoryBreakdown.map((cat) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                strings.isBn ? (cat.categoryNameBn ?? cat.categoryNameEn) : cat.categoryNameEn,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                cat.money.format(useBanglaDigits: settings.useBanglaDigits),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (cat.percentage / 100.0).clamp(0.0, 1.0),
                            backgroundColor: AppTheme.borderDark,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _parseColor(cat.color),
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cat.percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _selectedPeriodIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriodIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.incomeGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              amount,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppTheme.incomeGreen;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppTheme.incomeGreen;
    }
  }
}
