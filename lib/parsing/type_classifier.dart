class ParsedTypeResult {
  final String type; // expense, income, transfer, refund, loan_given, loan_received, loan_repayment
  final String? counterparty;
  final List<String> matchedTokens;
  final bool isExplicit;

  ParsedTypeResult({
    required this.type,
    this.counterparty,
    required this.matchedTokens,
    required this.isExplicit,
  });
}

class TypeClassifier {
  static ParsedTypeResult classify(String text) {
    final lower = text.toLowerCase();

    // 1. Loan repayment: ধার শোধ, ঋণ পরিশোধ, ঋণ শোধ
    if (lower.contains('ধার শোধ') || lower.contains('ঋণ পরিশোধ') || lower.contains('ঋণ শোধ') || lower.contains('repaid')) {
      final counterparty = _extractCounterparty(text);
      return ParsedTypeResult(
        type: 'loan_repayment',
        counterparty: counterparty,
        matchedTokens: ['ধার শোধ'],
        isExplicit: true,
      );
    }

    // 2. Loan given: ধার দিয়েছি, ধার দিলাম, ঋণ দিয়েছি, ঋণ দিলাম, lent
    if (lower.contains('ধার দিয়েছি') || lower.contains('ধার দিলাম') || lower.contains('ঋণ দিয়েছি') || lower.contains('lent')) {
      final counterparty = _extractCounterparty(text);
      return ParsedTypeResult(
        type: 'loan_given',
        counterparty: counterparty,
        matchedTokens: ['ধার দিয়েছি'],
        isExplicit: true,
      );
    }

    // 3. Loan received: ধার নিয়েছি, ধার নিলাম, ঋণ নিয়েছি, borrowed
    if (lower.contains('ধার নিয়েছি') || lower.contains('ধার নিলাম') || lower.contains('ঋণ নিয়েছি') || lower.contains('borrowed')) {
      final counterparty = _extractCounterparty(text);
      return ParsedTypeResult(
        type: 'loan_received',
        counterparty: counterparty,
        matchedTokens: ['ধার নিয়েছি'],
        isExplicit: true,
      );
    }

    // 4. Refund: রিফান্ড, ফেরত পেয়েছি, ফেরত পেলাম, refund
    if (lower.contains('রিফান্ড') || lower.contains('ফেরত পেয়েছি') || lower.contains('ফেরত পেলাম') || lower.contains('refund')) {
      return ParsedTypeResult(
        type: 'refund',
        matchedTokens: ['রিফান্ড'],
        isExplicit: true,
      );
    }

    // 5. Transfer: ট্রান্সফার, ক্যাশ আউট, ক্যাশআউট, cash out, cash in, পাঠিয়েছি
    if (lower.contains('ট্রান্সফার') || lower.contains('ক্যাশ আউট') || lower.contains('ক্যাশআউট') || lower.contains('cash out') || lower.contains('পাঠিয়েছি')) {
      return ParsedTypeResult(
        type: 'transfer',
        matchedTokens: ['ট্রান্সফার'],
        isExplicit: true,
      );
    }

    // 6. Income: বেতন, স্যালারি, আয়, ইনকাম, পেলাম, salary, received, বোনাস, বিক্রি
    if (lower.contains('বেতন') || lower.contains('স্যালারি') || lower.contains('ইনকাম') || lower.contains('আয়') ||
        lower.contains('বোনাস') || lower.contains('salary') || lower.contains('received') || lower.contains('পেয়েছি') || lower.contains('পেলাম')) {
      return ParsedTypeResult(
        type: 'income',
        matchedTokens: ['বেতন'],
        isExplicit: true,
      );
    }

    // 7. Expense (explicit verbs: কিনেছি, কিনলাম, খরচ, দিয়েছি, দিলাম, পরিশোধ, bill, ভাড়া, খেয়েছি, লেগেছে, paid, bought)
    final expenseKeywords = [
      'কিনেছি', 'কিনলাম', 'খরচ', 'দিয়েছি', 'দিলাম', 'পরিশোধ', 'বিল', 'bill',
      'ভাড়া', 'খেয়েছি', 'খেলাম', 'লেগেছে', 'paid', 'bought', 'expense'
    ];

    for (final kw in expenseKeywords) {
      if (lower.contains(kw)) {
        return ParsedTypeResult(
          type: 'expense',
          matchedTokens: [kw],
          isExplicit: true,
        );
      }
    }

    // Default is expense
    return ParsedTypeResult(
      type: 'expense',
      matchedTokens: [],
      isExplicit: false,
    );
  }

  static String? _extractCounterparty(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    for (int i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      // Check for word ending in কে (e.g. রহিমকে)
      if (t.endsWith('কে') && t.length > 2 && !t.startsWith('তা')) {
        return t.substring(0, t.length - 2);
      }
      // Check for 'from X' or 'থেকে X'
      if ((t == 'থেকে' || t == 'from') && i > 0) {
        return tokens[i - 1];
      }
      if ((t == 'to') && i + 1 < tokens.length) {
        return tokens[i + 1];
      }
    }
    return null;
  }
}
