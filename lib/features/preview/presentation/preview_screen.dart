import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/money/money.dart';
import '../../../data/db/app_database.dart';
import '../../../parsing/rule_parser.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final List<DraftTransaction> initialDrafts;

  const PreviewScreen({super.key, required this.initialDrafts});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late List<DraftTransaction> _drafts;
  List<CategoryEntry> _categories = [];
  List<AccountEntry> _accounts = [];

  @override
  void initState() {
    super.initState();
    _drafts = List.from(widget.initialDrafts);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final db = ref.read(databaseProvider);
    final cats = await db.select(db.categories).get();
    final accs = await db.select(db.accounts).get();
    if (mounted) {
      setState(() {
        _categories = cats;
        _accounts = accs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final strings = AppStrings(settings.locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.previewTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.discard, style: const TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
      body: _drafts.isEmpty
          ? Center(child: Text(strings.discard, style: const TextStyle(color: AppTheme.textMuted)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _drafts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildDraftCard(index, strings, settings.useBanglaDigits);
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _drafts.isEmpty ? null : () => _confirmSaveAll(strings),
            child: Text(strings.confirmSave),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(int index, AppStrings strings, bool useBanglaDigits) {
    final draft = _drafts[index];
    final isExpense = draft.type == 'expense';
    final amountController = TextEditingController(
      text: (draft.amountMinor / 100.0).toStringAsFixed(draft.amountMinor % 100 == 0 ? 0 : 2),
    );
    final descController = TextEditingController(text: draft.description);

    final currentCat = _categories.firstWhere(
      (c) => c.id == draft.categoryId,
      orElse: () => CategoryEntry(
        id: 'cat_uncategorized',
        nameEn: 'Uncategorized',
        nameBn: 'বিবিধ',
        kind: 'both',
        isSystem: 1,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    final currentAcc = _accounts.firstWhere(
      (a) => a.id == draft.accountId,
      orElse: () => AccountEntry(
        id: 'acc_cash',
        name: 'Cash',
        kind: 'cash',
        currency: 'BDT',
        openingBalanceMinor: 0,
        isDefault: 1,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    final pctConfidence = (draft.confidence * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Type Chip + Confidence Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: draft.type,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.cardDark,
                  items: [
                    'expense',
                    'income',
                    'transfer',
                    'refund',
                    'loan_given',
                    'loan_received',
                    'loan_repayment'
                  ].map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(
                        strings.typeLabel(t),
                        style: TextStyle(
                          color: t == 'income' ? AppTheme.incomeGreen : AppTheme.expenseRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _drafts[index] = draft.copyWith(type: val);
                      });
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: draft.confidence >= 0.8
                        ? AppTheme.incomeGreen.withValues(alpha: 0.15)
                        : AppTheme.neutralAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: draft.confidence >= 0.8
                          ? AppTheme.incomeGreen.withValues(alpha: 0.4)
                          : AppTheme.neutralAmber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    useBanglaDigits
                        ? '${Money.toBanglaDigits(pctConfidence.toString())}% আত্মবিশ্বাস'
                        : '$pctConfidence% Match',
                    style: TextStyle(
                      color: draft.confidence >= 0.8 ? AppTheme.incomeGreen : AppTheme.neutralAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount Field
            Row(
              children: [
                Text(
                  draft.currency == 'BDT' ? '৳' : '${draft.currency} ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isExpense ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(Money.toEnglishDigits(val));
                      if (parsed != null && parsed > 0) {
                        _drafts[index] = draft.copyWith(amountMinor: (parsed * 100).round());
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description Field
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: strings.description,
                isDense: true,
              ),
              onChanged: (val) {
                _drafts[index] = draft.copyWith(description: val.trim());
              },
            ),
            const SizedBox(height: 12),

            // Category & Account Pickers
            Row(
              children: [
                // Category
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: currentCat.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.category,
                      isDense: true,
                    ),
                    dropdownColor: AppTheme.cardDark,
                    items: _categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          strings.isBn ? (c.nameBn ?? c.nameEn) : c.nameEn,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _drafts[index] = draft.copyWith(categoryId: val);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Account
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: currentAcc.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.account,
                      isDense: true,
                    ),
                    dropdownColor: AppTheme.cardDark,
                    items: _accounts.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          a.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _drafts[index] = draft.copyWith(accountId: val);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSaveAll(AppStrings strings) async {
    final repo = ref.read(transactionRepositoryProvider);
    final savedIds = <String>[];

    for (final draft in _drafts) {
      final res = await repo.saveTransaction(draft, allowDuplicate: false);

      if (res.isFailure && res.errorOrNull == 'DUPLICATE_DETECTED') {
        if (!mounted) return;
        final allow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardDark,
            title: Text(strings.duplicateWarning),
            content: Text(
              strings.isBn
                  ? 'এই লেনদেনটি ইতিমধ্যে গত ১০ মিনিটের মধ্যে সেভ করা হয়েছে। আপনি কি আবার সেভ করতে চান?'
                  : 'An identical transaction was logged within the last 10 minutes. Do you want to save it anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(strings.discard),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(strings.saveAnyway),
              ),
            ],
          ),
        );

        if (allow == true) {
          final forcedRes = await repo.saveTransaction(draft, allowDuplicate: true);
          if (forcedRes.isSuccess) {
            savedIds.add(forcedRes.valueOrNull!);
          }
        }
      } else if (res.isSuccess) {
        savedIds.add(res.valueOrNull!);
      }
    }

    if (!mounted) return;

    if (savedIds.isNotEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.savedSuccess),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    }
  }
}
