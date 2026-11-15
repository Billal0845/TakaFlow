import 'normalizer.dart';

/// Parser for Bangla and English numbers, words, multipliers, and fractions.
/// Pure Dart - zero Flutter dependencies.
class BanglaNumberParser {
  static const Map<String, int> words0To99 = {
    'শূন্য': 0, 'এক': 1, 'দুই': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5,
    'ছয়': 6, 'সাত': 7, 'আট': 8, 'নয়': 9, 'দশ': 10,
    'এগারো': 11, 'বারো': 12, 'তেরো': 13, 'চৌদ্দ': 14, 'পনেরো': 15,
    'ষোলো': 16, 'সতেরো': 17, 'আঠারো': 18, 'ঊনিশ': 19, 'উনিশ': 19, 'বিশ': 20,
    'একুশ': 21, 'বাইশ': 22, 'তেইশ': 23, 'চব্বিশ': 24, 'চব্বিস': 24, 'পঁচিশ': 25,
    'ছাব্বিশ': 26, 'সাতাশ': 27, 'আঠাশ': 28, 'ঊনত্রিশ': 29, 'তিরিশ': 30, 'ত্রিশ': 30,
    'একত্রিশ': 31, 'বত্রিশ': 32, 'তেত্রিশ': 33, 'চৌত্রিশ': 34, 'পঁয়ত্রিশ': 35,
    'ছত্রিশ': 36, 'সাঁইত্রিশ': 37, 'আটত্রিশ': 38, 'ঊনচল্লিশ': 39, 'চল্লিশ': 40,
    'একচল্লিশ': 41, 'বিয়াল্লিশ': 42, 'তেতাল্লিশ': 43, 'চুয়াল্লিশ': 44, 'পঁয়তাল্লিশ': 45,
    'ছেচল্লিশ': 46, 'সাতচল্লিশ': 47, 'আটচল্লিশ': 48, 'ঊনপঞ্চাশ': 49, 'পঞ্চাশ': 50,
    'একান্ন': 51, 'বায়ান্ন': 52, 'তিপ্পান্ন': 53, 'চুয়ান্ন': 54, 'পঞ্চান্ন': 55,
    'ছাপ্পান্ন': 56, 'সাতান্ন': 57, 'আটান্ন': 58, 'ঊনষাট': 59, 'ষাট': 60,
    'একষট্টি': 61, 'বাষট্টি': 62, 'তেষট্টি': 63, 'চৌষট্টি': 64, 'পঁয়ষট্টি': 65,
    'ছেষট্টি': 66, 'সাতষট্টি': 67, 'আটষট্টি': 68, 'ঊনসত্তর': 69, 'সত্তর': 70,
    'একাত্তর': 71, 'বাহাত্তর': 72, 'তিয়াত্তর': 73, 'চুয়াত্তর': 74, 'পঁচাত্তর': 75,
    'ছিয়াত্তর': 76, 'সাতাত্তর': 77, 'আটাত্তর': 78, 'ঊনআশি': 79, 'আশি': 80,
    'একাশি': 81, 'বিরাশি': 82, 'তিরাশি': 83, 'চুরাশি': 84, 'পঁচাশি': 85,
    'ছিয়াশি': 86, 'সাতাশি': 87, 'অষ্টআশি': 88, 'আটাশি': 88, 'ঊননব্বই': 89, 'নব্বই': 90,
    'একানব্বই': 91, 'বানব্বই': 92, 'তিরানব্বই': 93, 'চুরানব্বই': 94, 'পঁচানব্বই': 95,
    'ছিয়ানব্বই': 96, 'সাতানব্বই': 97, 'আটানব্বই': 98, 'নিরানব্বই': 99,
  };

  static const Map<String, int> englishWords = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20,
    'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
    'eighty': 80, 'ninety': 90,
  };

  static const List<String> quantityUnits = [
    'কেজি', 'কেজিতে', 'গ্রাম', 'লিটার', 'লিটারে', 'টি', 'টা', 'খানা', 'জন', 'ঘণ্টা', 'ঘন্টা',
    'ডজন', 'পিস', 'প্যাকেট', 'kg', 'gm', 'liter', 'pcs', 'piece', 'packet'
  ];

  /// Extracts parsed amount in BDT minor units (poisha).
  /// E.g. "১২০ টাকা" -> 12000
  /// "দেড় হাজার" -> 150000
  /// "৬৫ হাজার" -> 6500000
  /// "ভাত ১২০ রিকশা ৪০" -> picks amount for fragment
  static ParsedAmountResult? parseFirstAmount(String input) {
    final text = Normalizer.normalize(input);
    final tokens = text.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    // First scan for multi-word or compound structures
    // Check known fraction words: দেড়, আড়াই, সাড়ে
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // দেড় হাজার / দেড় লাখ
      if (token == 'দেড়' || token == 'দের') {
        if (i + 1 < tokens.length) {
          final next = tokens[i + 1];
          final mult = _getMultiplier(next);
          if (mult > 0) {
            final minor = (1.5 * mult * 100).round();
            return ParsedAmountResult(amountMinor: minor, matchedTokens: [token, next]);
          }
        }
      }

      // আড়াই হাজার / আড়াই লাখ
      if (token == 'আড়াই' || token == 'আরাই') {
        if (i + 1 < tokens.length) {
          final next = tokens[i + 1];
          final mult = _getMultiplier(next);
          if (mult > 0) {
            final minor = (2.5 * mult * 100).round();
            return ParsedAmountResult(amountMinor: minor, matchedTokens: [token, next]);
          }
        }
      }

      // সাড়ে + number/multiplier: "সাড়ে তিন হাজার" -> 3500, "সাড়ে ১২০০" -> 1250, "সাড়ে বারোশো" -> 1250
      if (token == 'সাড়ে' || token == 'সারে') {
        if (i + 1 < tokens.length) {
          final next = tokens[i + 1];
          // E.g. সাড়ে ১২০০
          final numVal = num.tryParse(next);
          if (numVal != null) {
            // সাড়ে 1200 -> 1250
            final minor = ((numVal + 50) * 100).round();
            return ParsedAmountResult(amountMinor: minor, matchedTokens: [token, next]);
          }
          final wordNum = words0To99[next];
          if (wordNum != null) {
            if (i + 2 < tokens.length) {
              final next2 = tokens[i + 2];
              final mult = _getMultiplier(next2);
              if (mult > 0) {
                final minor = (((wordNum + 0.5) * mult) * 100).round();
                return ParsedAmountResult(amountMinor: minor, matchedTokens: [token, next, next2]);
              }
            }
          }
          if (next == 'বারোশো' || next == 'বারো শত') {
            return ParsedAmountResult(amountMinor: 125000, matchedTokens: [token, next]);
          }
        }
      }
    }

    // Now look for number + multiplier patterns: "65 হাজার", "65k", "2 লাখ", "পাঁচশো", "একশো বিশ"
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // E.g. "65k"
      final kMatch = RegExp(r'^(\d+(?:\.\d+)?)[kK]$').firstMatch(token);
      if (kMatch != null) {
        final val = num.parse(kMatch.group(1)!);
        return ParsedAmountResult(amountMinor: (val * 1000 * 100).round(), matchedTokens: [token]);
      }

      // Standalone Bengali compound numbers: "পাঁচশো" (500), "একশো" (100), "দুইশো" (200), "বারোশো" (1200)
      final compoundHundred = _parseCompoundHundred(token);
      if (compoundHundred != null) {
        // Check if followed by tens/units: "একশো বিশ"
        int total = compoundHundred;
        final matched = [token];
        if (i + 1 < tokens.length) {
          final next = tokens[i + 1];
          final nextNum = num.tryParse(next) ?? words0To99[next] ?? englishWords[next];
          if (nextNum != null && nextNum < 100) {
            total += nextNum.toInt();
            matched.add(next);
          }
        }
        return ParsedAmountResult(amountMinor: total * 100, matchedTokens: matched);
      }

      // Check numeric or word value
      final numVal = num.tryParse(token) ?? words0To99[token] ?? englishWords[token];
      if (numVal != null) {
        // Check if next token is a quantity unit: "2 কেজি" -> Skip!
        if (i + 1 < tokens.length && quantityUnits.contains(tokens[i + 1])) {
          continue;
        }

        // Check if followed by multiplier: "65 হাজার", "2 লাখ"
        if (i + 1 < tokens.length) {
          final mult = _getMultiplier(tokens[i + 1]);
          if (mult > 0) {
            final minor = (numVal * mult * 100).round();
            return ParsedAmountResult(
              amountMinor: minor,
              matchedTokens: [token, tokens[i + 1]],
            );
          }
        }

        // Check if followed by currency token: "120 টাকা" or "120 tk"
        if (i + 1 < tokens.length && _isCurrencyToken(tokens[i + 1])) {
          return ParsedAmountResult(
            amountMinor: (numVal * 100).round(),
            matchedTokens: [token, tokens[i + 1]],
          );
        }

        // Check if preceded by currency token: "টাকা 120"
        if (i > 0 && _isCurrencyToken(tokens[i - 1])) {
          return ParsedAmountResult(
            amountMinor: (numVal * 100).round(),
            matchedTokens: [tokens[i - 1], token],
          );
        }
      }
    }

    // Fallback: search for any standalone number not tied to a quantity unit
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      // Strip trailing punctuation
      final clean = token.replaceAll(RegExp(r'[^0-9.]'), '');
      final val = num.tryParse(clean);
      if (val != null && val > 0) {
        // Ensure not followed by a quantity unit
        if (i + 1 < tokens.length && quantityUnits.contains(tokens[i + 1])) {
          continue;
        }
        return ParsedAmountResult(
          amountMinor: (val * 100).round(),
          matchedTokens: [token],
        );
      }
    }

    return null;
  }

  static int? _parseCompoundHundred(String word) {
    const map = {
      'একশো': 100, 'একশ': 100, 'একশত': 100,
      'দুইশো': 200, 'দুইশ': 200, 'দুশো': 200,
      'তিনশো': 300, 'তিনশ': 300,
      'চারশো': 400, 'চারশ': 400,
      'পাঁচশো': 500, 'পাঁচশ': 500, 'পাচশো': 500, 'পাচশ': 500,
      'ছয়শো': 600, 'ছয়শ': 600,
      'সাতশো': 700, 'সাতশ': 700,
      'আটশো': 800, 'আটশ': 800,
      'নয়শো': 900, 'নয়শ': 900,
      'বারোশো': 1200, 'পনেরোশো': 1500,
    };
    return map[word];
  }

  static int _getMultiplier(String token) {
    final lower = token.toLowerCase();
    if (lower == 'হাজার' || lower == 'hajar' || lower == 'hazar' || lower == 'thousand') {
      return 1000;
    }
    if (lower == 'লাখ' || lower == 'লক্ষ' || lower == 'lakh' || lower == 'lac') {
      return 100000;
    }
    if (lower == 'কোটি' || lower == 'crore' || lower == 'koti') {
      return 10000000;
    }
    if (lower == 'শ' || lower == 'শো' || lower == 'শত' || lower == 'hundred') {
      return 100;
    }
    return 0;
  }

  static bool _isCurrencyToken(String token) {
    final t = token.toLowerCase();
    return t == 'টাকা' || t == 'tk' || t == 'taka' || t == 'bdt' || t == '৳';
  }
}

class ParsedAmountResult {
  final int amountMinor;
  final List<String> matchedTokens;

  ParsedAmountResult({
    required this.amountMinor,
    required this.matchedTokens,
  });
}
