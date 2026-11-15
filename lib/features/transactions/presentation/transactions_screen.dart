import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/money/money.dart';
import '../../../domain/repositories/transaction_repository.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _selectedType = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final strings = AppStrings(settings.locale);
    final repo = ref.watch(transactionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.transactions),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: strings.isBn ? 'লেনদেন খুঁজুন...' : 'Search transactions...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('all', strings.isBn ? 'সকল' : 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('expense', strings.typeLabel('expense')),
                const SizedBox(width: 8),
                _buildFilterChip('income', strings.typeLabel('income')),
                const SizedBox(width: 8),
                _buildFilterChip('transfer', strings.typeLabel('transfer')),
                const SizedBox(width: 8),
                _buildFilterChip('loan_given', strings.typeLabel('loan_given')),
              ],
            ),
          ),

          // Transaction List Stream
          Expanded(
            child: StreamBuilder<List<TransactionWithDetails>>(
              stream: repo.watchTransactions(
                type: _selectedType == 'all' ? null : _selectedType,
                searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      strings.isBn ? 'কোনো লেনদেন পাওয়া যায়নি' : 'No transactions found',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  );
                }

                // Group by local date
                final Map<String, List<TransactionWithDetails>> grouped = {};
                for (final item in list) {
                  final d = item.transaction.localDate;
                  grouped.putIfAbsent(d, () => []).add(item);
                }

                final sortedDates = grouped.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, dateIndex) {
                    final date = sortedDates[dateIndex];
                    final dayItems = grouped[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            date,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...dayItems.map((item) {
                          return _buildTransactionTile(item, strings, settings.useBanglaDigits, repo);
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppTheme.incomeGreen.withValues(alpha: 0.2),
      backgroundColor: AppTheme.cardDark,
      side: BorderSide(
        color: isSelected ? AppTheme.incomeGreen : AppTheme.borderDark,
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.incomeGreen : AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedType = type;
          });
        }
      },
    );
  }

  Widget _buildTransactionTile(
    TransactionWithDetails item,
    AppStrings strings,
    bool useBanglaDigits,
    TransactionRepository repo,
  ) {
    final tx = item.transaction;
    final isExpense = tx.type == 'expense';
    final isIncome = tx.type == 'income';
    final money = Money.fromMinor(tx.amountMinor, tx.currency);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.expenseRed.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline, color: AppTheme.expenseRed),
      ),
      onDismissed: (_) async {
        await repo.deleteTransaction(tx.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.isBn ? 'মুছে ফেলা হয়েছে' : 'Deleted'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: strings.undo,
                textColor: AppTheme.incomeGreen,
                onPressed: () async {
                  await repo.restoreTransaction(tx.id);
                },
              ),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIncome
                  ? AppTheme.incomeGreen.withValues(alpha: 0.1)
                  : AppTheme.expenseRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward
                  : (isExpense ? Icons.arrow_upward : Icons.swap_horiz),
              color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
              size: 20,
            ),
          ),
          title: Text(
            tx.description.isNotEmpty ? tx.description : strings.typeLabel(tx.type),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            '${item.category?.nameBn ?? item.category?.nameEn ?? "বিবিধ"} • ${item.account?.name ?? "Cash"}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          trailing: Text(
            '${isIncome ? "+" : (isExpense ? "-" : "")}${money.format(useBanglaDigits: useBanglaDigits)}',
            style: TextStyle(
              color: isIncome ? AppTheme.incomeGreen : (isExpense ? AppTheme.expenseRed : AppTheme.textPrimary),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
