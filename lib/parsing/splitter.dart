import 'bangla_numbers.dart';

class SentenceSplitter {
  /// Splits a sentence into candidate fragments if multiple money amounts exist.
  /// E.g. "ভাত ১২০, রিকশা ৪০" -> ["ভাত ১২০", "রিকশা ৪০"]
  /// "বাজার করেছি এবং ডিম কিনেছি" (only 1 or 0 amounts) -> ["বাজার করেছি এবং ডিম কিনেছি"]
  static List<String> splitSentence(String text) {
    if (text.trim().isEmpty) return [];

    // Split on conjunctions and punctuation: comma, এবং, আর, and
    final delimiters = RegExp(r'[,;]|\bএবং\b|\bআর\b|\band\b', caseSensitive: false);
    final rawParts = text.split(delimiters).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (rawParts.length <= 1) {
      return [text.trim()];
    }

    // Verify if multiple parts contain independent amounts
    int partsWithAmount = 0;
    for (final part in rawParts) {
      if (BanglaNumberParser.parseFirstAmount(part) != null) {
        partsWithAmount++;
      }
    }

    // If at least 2 parts contain amounts, split!
    if (partsWithAmount >= 2) {
      return rawParts.where((p) => BanglaNumberParser.parseFirstAmount(p) != null).toList();
    }

    // Otherwise, treat as one transaction
    return [text.trim()];
  }
}
