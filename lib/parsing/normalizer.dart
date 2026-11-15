/// Normalizer for user text and STT transcripts.
/// Pure Dart - zero Flutter dependencies.
class Normalizer {
  static const Map<String, String> _banglaToEnglishDigits = {
    '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
    '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
  };

  static const Map<String, String> _sttFixes = {
    'ট্যাকা': 'টাকা',
    'টেকা': 'টাকা',
    'টাকাটা': 'টাকা',
    'টাকার': 'টাকা',
    'টাঃ': 'টাকা',
    'tk': 'টাকা',
    'taka': 'টাকা',
    'bdt': 'টাকা',
    '৳': 'টাকা',
    'রিচাজ': 'রিচার্জ',
    'রিকসা': 'রিকশা',
    'রিক্সা': 'রিকশা',
    'সি এন জি': 'সিএনজি',
    'বিকাশএ': 'বিকাশে',
    'নগদএ': 'নগদে',
  };

  /// Normalizes transcript text:
  /// 1. Converts Bangla digits to standard 0-9.
  /// 2. Removes Bengali danda (।) and normalizes punctuation.
  /// 3. Replaces common STT phonetic variations.
  /// 4. Collapses extra spaces.
  static String normalize(String input) {
    if (input.trim().isEmpty) return '';

    // Convert digits
    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      sb.write(_banglaToEnglishDigits[ch] ?? ch);
    }
    var text = sb.toString();

    // Remove thousands commas inside digits: e.g. "65,000" -> "65000", "1,50,000" -> "150000"
    text = text.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}${m[2]}');

    // Remove danda, replace with comma or period
    text = text.replaceAll('।', ' , ');

    // Standardize remaining commas and semicolons
    text = text.replaceAll(RegExp(r'[,;]'), ' , ');

    // Lowercase Latin tokens
    text = text.split(' ').map((token) {
      // Check if pure latin
      if (RegExp(r'^[a-zA-Z]+$').hasMatch(token)) {
        return token.toLowerCase();
      }
      return token;
    }).join(' ');

    // Apply STT fixes
    for (final entry in _sttFixes.entries) {
      text = text.replaceAll(RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false), entry.value);
    }

    // Collapse multiple whitespaces
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
