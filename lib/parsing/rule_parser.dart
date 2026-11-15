import '../core/money/money.dart';
import '../core/time/clock.dart';
import 'bangla_numbers.dart';
import 'category_matcher.dart';
import 'date_parser.dart';
import 'normalizer.dart';
import 'splitter.dart';
import 'type_classifier.dart';

class DraftTransaction {
  final String type;
  final int amountMinor;
  final String currency;
  final String description;
  final String? categoryId;
  final String? subcategoryId;
  final String? itemTag;
  final String localDate;
  final int occurredAtUtc;
  final String accountId;
  final String? counterparty;
  final List<String> spendingNature;
  final double confidence;
  final String sourceText;
  final String sourceFragment;
  final List<String> flags;
  final String source;

  DraftTransaction({
    required this.type,
    required this.amountMinor,
    this.currency = 'BDT',
    required this.description,
    this.categoryId,
    this.subcategoryId,
    this.itemTag,
    required this.localDate,
    required this.occurredAtUtc,
    this.accountId = 'acc_cash',
    this.counterparty,
    this.spendingNature = const [],
    required this.confidence,
    required this.sourceText,
    required this.sourceFragment,
    this.flags = const [],
    this.source = 'rules',
  });

  Money get money => Money.fromMinor(amountMinor, currency);

  DraftTransaction copyWith({
    String? type,
    int? amountMinor,
    String? currency,
    String? description,
    String? categoryId,
    String? subcategoryId,
    String? itemTag,
    String? localDate,
    int? occurredAtUtc,
    String? accountId,
    String? counterparty,
    List<String>? spendingNature,
    double? confidence,
    String? sourceText,
    String? sourceFragment,
    List<String>? flags,
    String? source,
  }) {
    return DraftTransaction(
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      itemTag: itemTag ?? this.itemTag,
      localDate: localDate ?? this.localDate,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      accountId: accountId ?? this.accountId,
      counterparty: counterparty ?? this.counterparty,
      spendingNature: spendingNature ?? this.spendingNature,
      confidence: confidence ?? this.confidence,
      sourceText: sourceText ?? this.sourceText,
      sourceFragment: sourceFragment ?? this.sourceFragment,
      flags: flags ?? this.flags,
      source: source ?? this.source,
    );
  }
}

class RuleParser {
  final Clock clock;
  final CategoryMatcher categoryMatcher;

  RuleParser({
    required this.clock,
    required this.categoryMatcher,
  });

  List<DraftTransaction> parse(String rawTranscript) {
    if (rawTranscript.trim().isEmpty) return [];

    final normalized = Normalizer.normalize(rawTranscript);
    final fragments = SentenceSplitter.splitSentence(normalized);
    final drafts = <DraftTransaction>[];

    final dateParser = DateParser(clock);

    for (final fragment in fragments) {
      double score = 0.0;
      final flags = <String>[];

      // 1. Amount
      final amountResult = BanglaNumberParser.parseFirstAmount(fragment);
      final int amountMinor;
      if (amountResult != null) {
        amountMinor = amountResult.amountMinor;
        score += 0.35;
      } else {
        amountMinor = 0;
        flags.add('noAmountFound');
      }

      // 2. Type
      final typeResult = TypeClassifier.classify(fragment);
      if (typeResult.isExplicit) {
        score += 0.25;
      } else {
        score += 0.10;
      }

      // 3. Date
      final dateResult = dateParser.parseDate(fragment);
      if (dateResult.isExplicit) {
        score += 0.10;
      } else {
        score += 0.05;
      }

      // 4. Category
      final catMatch = categoryMatcher.matchCategory(fragment);
      String? catId;
      String? subcatId;
      if (catMatch != null) {
        catId = catMatch.categoryId;
        subcatId = catMatch.subcategoryId;
        score += 0.20;
      } else {
        catId = 'cat_uncategorized';
        flags.add('uncategorized');
      }

      // 5. Clean description
      var desc = _buildDescription(fragment, amountResult, dateResult, typeResult, catMatch);
      if (desc.isNotEmpty) {
        score += 0.10;
      } else {
        desc = catMatch?.matchedKeyword ?? typeResult.type;
      }

      // Zero confidence if no amount
      if (amountMinor <= 0) {
        score = 0.0;
      }

      drafts.add(DraftTransaction(
        type: typeResult.type,
        amountMinor: amountMinor > 0 ? amountMinor : 10000, // Fallback placeholder if zero
        currency: 'BDT',
        description: desc,
        categoryId: catId,
        subcategoryId: subcatId,
        localDate: dateResult.localDate,
        occurredAtUtc: dateResult.occurredAt.toUtc().millisecondsSinceEpoch,
        accountId: 'acc_cash',
        counterparty: typeResult.counterparty,
        confidence: score.clamp(0.0, 1.0),
        sourceText: rawTranscript,
        sourceFragment: fragment,
        flags: flags,
        source: 'rules',
      ));
    }

    return drafts;
  }

  String _buildDescription(
    String fragment,
    ParsedAmountResult? amountResult,
    ParsedDateResult dateResult,
    ParsedTypeResult typeResult,
    CategoryMatch? catMatch,
  ) {
    var words = fragment.split(RegExp(r'\s+')).toList();

    // Remove amount tokens
    if (amountResult != null) {
      for (final t in amountResult.matchedTokens) {
        words.remove(t);
      }
    }
    // Remove date tokens
    for (final t in dateResult.matchedTokens) {
      words.remove(t);
    }
    // Remove explicit type tokens
    for (final t in typeResult.matchedTokens) {
      words.remove(t);
    }
    // Remove standalone 'টাকা' / 'tk'
    words.removeWhere((w) => w == 'টাকা' || w == 'tk' || w == 'taka');

    final clean = words.join(' ').replaceAll(RegExp(r'[,;]'), '').trim();
    return clean;
  }
}
