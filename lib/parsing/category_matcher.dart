class CategoryMatch {
  final String categoryId;
  final String? subcategoryId;
  final double score;
  final String matchedKeyword;

  CategoryMatch({
    required this.categoryId,
    this.subcategoryId,
    required this.score,
    required this.matchedKeyword,
  });
}

class CategoryKeywordEntry {
  final String keyword;
  final String categoryId;
  final String? subcategoryId;
  final double weight;

  const CategoryKeywordEntry({
    required this.keyword,
    required this.categoryId,
    this.subcategoryId,
    this.weight = 1.0,
  });

  factory CategoryKeywordEntry.fromJson(Map<String, dynamic> json) {
    return CategoryKeywordEntry(
      keyword: json['keyword'] as String,
      categoryId: json['category_id'] as String,
      subcategoryId: json['sub_id'] as String?,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class CategoryMatcher {
  final List<CategoryKeywordEntry> keywords;

  CategoryMatcher(this.keywords);

  /// Strips common Bangla suffixes for lemmatization
  static String lemmatize(String word) {
    var w = word.trim().toLowerCase();
    const suffixes = ['গুলো', 'গুলি', 'দের', 'দেরকে', 'কে', 'ের', 'তে', 'ে', 'র', 'টা', 'টি', 'খানা'];
    for (final s in suffixes) {
      if (w.length > s.length + 2 && w.endsWith(s)) {
        w = w.substring(0, w.length - s.length);
        break;
      }
    }
    return w;
  }

  CategoryMatch? matchCategory(String text) {
    if (keywords.isEmpty) return null;

    final lowerText = text.toLowerCase();
    final tokens = lowerText.split(RegExp(r'\s+'));
    final lemmatizedTokens = tokens.map(lemmatize).toList();

    CategoryMatch? bestMatch;

    for (final entry in keywords) {
      final kw = entry.keyword.toLowerCase();

      // Exact phrase match in sentence
      if (lowerText.contains(kw)) {
        final score = entry.weight + (entry.subcategoryId != null ? 0.2 : 0.0);
        if (bestMatch == null || score > bestMatch.score) {
          bestMatch = CategoryMatch(
            categoryId: entry.categoryId,
            subcategoryId: entry.subcategoryId,
            score: score,
            matchedKeyword: kw,
          );
        }
        continue;
      }

      // Token/lemmatized match
      final lemmatizedKw = lemmatize(kw);
      for (final t in lemmatizedTokens) {
        if (t == lemmatizedKw || t == kw) {
          final score = entry.weight;
          if (bestMatch == null || score > bestMatch.score) {
            bestMatch = CategoryMatch(
              categoryId: entry.categoryId,
              subcategoryId: entry.subcategoryId,
              score: score,
              matchedKeyword: kw,
            );
          }
        }
      }
    }

    return bestMatch;
  }
}
