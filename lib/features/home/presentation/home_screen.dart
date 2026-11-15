import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/money/money.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../integrations/stt/voice_capture_service.dart';
import '../../preview/presentation/preview_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToTransactions;

  const HomeScreen({super.key, required this.onNavigateToTransactions});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _sentenceController = TextEditingController();
  final VoiceCaptureService _voiceService = VoiceCaptureService();
  bool _isListening = false;
  String _liveTranscript = '';

  @override
  void dispose() {
    _sentenceController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  Future<void> _handleVoiceTap(AppStrings strings) async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      if (_liveTranscript.trim().isNotEmpty) {
        _processText(_liveTranscript);
      }
    } else {
      final available = await _voiceService.init();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.isBn
                    ? 'মাইক্রোফোন চালু করা যায়নি। অনুগ্রহ করে টাইপ করে ইনপুট দিন।'
                    : 'Speech recognition unavailable. Please use text input.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
        _liveTranscript = '';
      });

      await _voiceService.startListening(
        onResult: (text) {
          setState(() {
            _liveTranscript = text;
          });
        },
      );
    }
  }

  Future<void> _processText(String text) async {
    if (text.trim().isEmpty) return;

    final parser = await ref.read(ruleParserProvider.future);
    final drafts = parser.parse(text);

    if (!mounted) return;

    if (drafts.isNotEmpty) {
      _sentenceController.clear();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(initialDrafts: drafts),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final strings = AppStrings(settings.locale);
    final clock = ref.watch(clockProvider);
    final todayStr = clock.todayLocalDate();
    final txRepo = ref.watch(transactionRepositoryProvider);
    final reportRepo = ref.watch(reportRepositoryProvider);

    final now = clock.now();
    final startOfMonth = clock.toLocalDate(DateTime(now.year, now.month, 1));

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Today & Month Spending Overview Cards
          FutureBuilder(
            future: Future.wait([
              reportRepo.getReportForDateRange(fromDate: todayStr, toDate: todayStr),
              reportRepo.getReportForDateRange(fromDate: startOfMonth, toDate: todayStr),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              final todayReport = snapshot.data?[0];
              final monthReport = snapshot.data?[1];

              final todayExpense = todayReport != null ? todayReport.totalExpense : Money.zero;
              final monthExpense = monthReport != null ? monthReport.totalExpense : Money.zero;

              return Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.todaySpending,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              todayExpense.format(useBanglaDigits: settings.useBanglaDigits),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.expenseRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.monthSpending,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              monthExpense.format(useBanglaDigits: settings.useBanglaDigits),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Central Microphone Capture Button (FR-1)
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _handleVoiceTap(strings),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? AppTheme.expenseRed : AppTheme.incomeGreen,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? AppTheme.expenseRed : AppTheme.incomeGreen)
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isListening ? strings.listening : strings.tapToSpeak,
                  style: TextStyle(
                    color: _isListening ? AppTheme.expenseRed : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_liveTranscript.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Text(
                      _liveTranscript,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Typed sentence input field (FR-3)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sentenceController,
                  decoration: InputDecoration(
                    hintText: strings.typeSentenceHint,
                    prefixIcon: const Icon(Icons.keyboard, color: AppTheme.textMuted),
                    isDense: true,
                  ),
                  onSubmitted: _processText,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.incomeGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                onPressed: () => _processText(_sentenceController.text),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Transactions Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.recentTransactions,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              TextButton(
                onPressed: widget.onNavigateToTransactions,
                child: Text(strings.viewAll, style: const TextStyle(color: AppTheme.incomeGreen)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Recent 5 transactions
          StreamBuilder<List<TransactionWithDetails>>(
            stream: txRepo.watchTransactions(),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              final recent = list.take(5).toList();

              if (recent.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        strings.isBn ? 'এখনও কোনো লেনদেন নেই' : 'No transactions yet',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: recent.map((item) {
                  final tx = item.transaction;
                  final isExpense = tx.type == 'expense';
                  final isIncome = tx.type == 'income';
                  final money = Money.fromMinor(tx.amountMinor, tx.currency);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      title: Text(
                        tx.description.isNotEmpty ? tx.description : strings.typeLabel(tx.type),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${tx.localDate} • ${item.category?.nameBn ?? item.category?.nameEn ?? "বিবিধ"}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      trailing: Text(
                        '${isIncome ? "+" : (isExpense ? "-" : "")}${money.format(useBanglaDigits: settings.useBanglaDigits)}',
                        style: TextStyle(
                          color: isIncome ? AppTheme.incomeGreen : (isExpense ? AppTheme.expenseRed : AppTheme.textPrimary),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
