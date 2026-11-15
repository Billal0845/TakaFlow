import '../core/time/clock.dart';

class ParsedDateResult {
  final DateTime occurredAt;
  final String localDate;
  final List<String> matchedTokens;
  final bool isExplicit;

  ParsedDateResult({
    required this.occurredAt,
    required this.localDate,
    required this.matchedTokens,
    required this.isExplicit,
  });
}

class DateParser {
  final Clock clock;

  const DateParser(this.clock);

  static const Map<String, int> banglaMonths = {
    'জানুয়ারি': 1, 'জানুয়ারি': 1, 'january': 1, 'jan': 1,
    'ফেব্রুয়ারি': 2, 'ফেব্রুয়ারি': 2, 'february': 2, 'feb': 2,
    'মার্চ': 3, 'march': 3, 'mar': 3,
    'এপ্রিল': 4, 'april': 4, 'apr': 4,
    'মে': 5, 'may': 5,
    'জুন': 6, 'june': 6, 'jun': 6,
    'জুলাই': 7, 'july': 7, 'jul': 7,
    'আগস্ট': 8, 'august': 8, 'aug': 8,
    'সেপ্টেম্বর': 9, 'september': 9, 'sep': 9,
    'অক্টোবর': 10, 'october': 10, 'oct': 10,
    'নভেম্বর': 11, 'november': 11, 'nov': 11,
    'ডিসেম্বর': 12, 'december': 12, 'dec': 12,
  };

  ParsedDateResult parseDate(String text) {
    final now = clock.now();
    final tokens = text.split(RegExp(r'\s+'));

    // 1. Check relative date keywords
    for (int i = 0; i < tokens.length; i++) {
      final t = tokens[i].toLowerCase();

      if (t == 'আজ' || t == 'আজকে' || t == 'today') {
        return ParsedDateResult(
          occurredAt: now,
          localDate: clock.toLocalDate(now),
          matchedTokens: [tokens[i]],
          isExplicit: true,
        );
      }

      if (t == 'গতকাল' || t == 'কাল' || t == 'yesterday') {
        final dt = now.subtract(const Duration(days: 1));
        return ParsedDateResult(
          occurredAt: dt,
          localDate: clock.toLocalDate(dt),
          matchedTokens: [tokens[i]],
          isExplicit: true,
        );
      }

      if (t == 'পরশু' || t == 'পরশুদিন') {
        final dt = now.subtract(const Duration(days: 2));
        return ParsedDateResult(
          occurredAt: dt,
          localDate: clock.toLocalDate(dt),
          matchedTokens: [tokens[i]],
          isExplicit: true,
        );
      }

      // N দিন আগে
      if (t == 'আগে' && i >= 2 && (tokens[i - 1] == 'দিন' || tokens[i - 1] == 'দিনের')) {
        final days = int.tryParse(tokens[i - 2]);
        if (days != null && days > 0 && days < 400) {
          final dt = now.subtract(Duration(days: days));
          return ParsedDateResult(
            occurredAt: dt,
            localDate: clock.toLocalDate(dt),
            matchedTokens: [tokens[i - 2], tokens[i - 1], tokens[i]],
            isExplicit: true,
          );
        }
      }

      // গত সপ্তাহ
      if (t == 'সপ্তাহ' && i > 0 && tokens[i - 1] == 'গত') {
        final dt = now.subtract(const Duration(days: 7));
        return ParsedDateResult(
          occurredAt: dt,
          localDate: clock.toLocalDate(dt),
          matchedTokens: [tokens[i - 1], tokens[i]],
          isExplicit: true,
        );
      }
    }

    // 2. Explicit date parsing: e.g. "১২ নভেম্বর", "12/11", "12 nov"
    for (int i = 0; i < tokens.length - 1; i++) {
      final day = int.tryParse(tokens[i]);
      if (day != null && day >= 1 && day <= 31) {
        final monthStr = tokens[i + 1].toLowerCase();
        final month = banglaMonths[monthStr];
        if (month != null) {
          int year = now.year;
          if (month > now.month) {
            year -= 1; // Last year if future month
          }
          final dt = DateTime(year, month, day, now.hour, now.minute);
          return ParsedDateResult(
            occurredAt: dt,
            localDate: clock.toLocalDate(dt),
            matchedTokens: [tokens[i], tokens[i + 1]],
            isExplicit: true,
          );
        }
      }
    }

    // Default to today
    return ParsedDateResult(
      occurredAt: now,
      localDate: clock.toLocalDate(now),
      matchedTokens: [],
      isExplicit: false,
    );
  }
}
