/// Money value object.
/// Always stores amounts in integer minor units (e.g. 1 BDT = 100 poisha).
/// Never use floating-point types for currency calculations.
class Money implements Comparable<Money> {
  final int amountMinor;
  final String currency;

  const Money({
    required this.amountMinor,
    this.currency = 'BDT',
  });

  factory Money.fromMinor(int minor, [String currency = 'BDT']) {
    return Money(amountMinor: minor, currency: currency);
  }

  factory Money.fromMajor(num major, [String currency = 'BDT']) {
    return Money(
      amountMinor: (major * 100).round(),
      currency: currency,
    );
  }

  static const Money zero = Money(amountMinor: 0);

  double get majorValue => amountMinor / 100.0;
  bool get isNegative => amountMinor < 0;
  bool get isZero => amountMinor == 0;
  bool get isPositive => amountMinor > 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor: amountMinor + other.amountMinor, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor: amountMinor - other.amountMinor, currency: currency);
  }

  Money operator *(num factor) {
    return Money(
      amountMinor: (amountMinor * factor).round(),
      currency: currency,
    );
  }

  Money abs() => Money(amountMinor: amountMinor.abs(), currency: currency);

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amountMinor == other.amountMinor &&
          currency == other.currency;

  @override
  int get hashCode => amountMinor.hashCode ^ currency.hashCode;

  /// Formats money string. E.g. "৳120", "৳120.50", "৳১২০"
  String format({bool useBanglaDigits = false, bool showSymbol = true}) {
    final symbol = showSymbol ? (currency == 'BDT' ? '৳' : '$currency ') : '';
    final sign = amountMinor < 0 ? '-' : '';
    final absMinor = amountMinor.abs();
    final major = absMinor ~/ 100;
    final minor = absMinor % 100;

    String text;
    if (minor == 0) {
      text = '$major';
    } else {
      text = '$major.${minor.toString().padLeft(2, '0')}';
    }

    if (useBanglaDigits) {
      text = toBanglaDigits(text);
    }

    return '$sign$symbol$text';
  }

  static String toBanglaDigits(String input) {
    const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        sb.write(banglaDigits[code - 48]);
      } else {
        sb.write(input[i]);
      }
    }
    return sb.toString();
  }

  static String toEnglishDigits(String input) {
    const banglaToEnglish = {
      '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
      '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
    };
    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      sb.write(banglaToEnglish[ch] ?? ch);
    }
    return sb.toString();
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot calculate between $currency and ${other.currency}');
    }
  }

  @override
  String toString() => format();
}
