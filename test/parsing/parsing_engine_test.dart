import 'package:flutter_test/flutter_test.dart';
import 'package:self_accountant/core/money/money.dart';
import 'package:self_accountant/core/time/clock.dart';
import 'package:self_accountant/parsing/bangla_numbers.dart';
import 'package:self_accountant/parsing/category_matcher.dart';
import 'package:self_accountant/parsing/normalizer.dart';
import 'package:self_accountant/parsing/rule_parser.dart';
import 'package:self_accountant/parsing/splitter.dart';

void main() {
  group('Money Value Object', () {
    test('creates from minor and major units', () {
      final m1 = Money.fromMinor(12050); // 120.50 BDT
      expect(m1.amountMinor, 12050);
      expect(m1.majorValue, 120.50);

      final m2 = Money.fromMajor(120.50);
      expect(m2.amountMinor, 12050);
      expect(m1, equals(m2));
    });

    test('performs exact arithmetic without rounding drift', () {
      final a = Money.fromMajor(10.10);
      final b = Money.fromMajor(20.20);
      final c = a + b;
      expect(c.amountMinor, 3030); // 30.30 BDT
      expect(c.majorValue, 30.30);
    });

    test('formats English and Bangla digits correctly', () {
      final m = Money.fromMinor(12050);
      expect(m.format(useBanglaDigits: false), '৳120.50');
      expect(m.format(useBanglaDigits: true), '৳১২০.৫০');

      final whole = Money.fromMinor(50000);
      expect(whole.format(useBanglaDigits: false), '৳500');
      expect(whole.format(useBanglaDigits: true), '৳৫০০');
    });
  });

  group('Normalizer', () {
    test('converts Bangla digits and normalizes spaces and danda', () {
      final raw = 'আজকে   ১২০   টাকা দিয়ে ভাত খেলাম।';
      final res = Normalizer.normalize(raw);
      expect(res, contains('120'));
      expect(res, contains('টাকা'));
      expect(res.contains('।'), isFalse);
    });
  });

  group('Bangla Number Parser (Section 7.2 Spec Table)', () {
    test('parses exact digits and commas', () {
      expect(BanglaNumberParser.parseFirstAmount('65000')?.amountMinor, 6500000);
      expect(BanglaNumberParser.parseFirstAmount('৬৫০০০')?.amountMinor, 6500000);
    });

    test('parses multipliers: 65 হাজার, 65 hajar, 65k', () {
      expect(BanglaNumberParser.parseFirstAmount('65 হাজার')?.amountMinor, 6500000);
      expect(BanglaNumberParser.parseFirstAmount('65 hajar')?.amountMinor, 6500000);
      expect(BanglaNumberParser.parseFirstAmount('65k')?.amountMinor, 6500000);
    });

    test('parses fractions: দেড় হাজার, আড়াই হাজার, সাড়ে তিন হাজার', () {
      expect(BanglaNumberParser.parseFirstAmount('দেড় হাজার')?.amountMinor, 150000);
      expect(BanglaNumberParser.parseFirstAmount('আড়াই হাজার')?.amountMinor, 250000);
      expect(BanglaNumberParser.parseFirstAmount('সাড়ে তিন হাজার')?.amountMinor, 350000);
    });

    test('parses সাড়ে ১২০০ / সাড়ে বারোশো', () {
      expect(BanglaNumberParser.parseFirstAmount('সাড়ে ১২০০')?.amountMinor, 125000);
      expect(BanglaNumberParser.parseFirstAmount('সাড়ে বারোশো')?.amountMinor, 125000);
    });

    test('parses lakhs and crores: এক লাখ, ১.৫ লাখ, দেড় লাখ, দুই কোটি', () {
      expect(BanglaNumberParser.parseFirstAmount('এক লাখ')?.amountMinor, 10000000);
      expect(BanglaNumberParser.parseFirstAmount('1.5 লাখ')?.amountMinor, 15000000);
      expect(BanglaNumberParser.parseFirstAmount('দেড় লাখ')?.amountMinor, 15000000);
      expect(BanglaNumberParser.parseFirstAmount('দুই কোটি')?.amountMinor, 2000000000);
    });

    test('parses hundreds: পাঁচশো, ৫০০, একশো বিশ', () {
      expect(BanglaNumberParser.parseFirstAmount('পাঁচশো')?.amountMinor, 50000);
      expect(BanglaNumberParser.parseFirstAmount('৫০০')?.amountMinor, 50000);
      expect(BanglaNumberParser.parseFirstAmount('একশো বিশ')?.amountMinor, 12000);
    });

    test('parses decimals: 120.50, ১২০.৫০', () {
      expect(BanglaNumberParser.parseFirstAmount('120.50')?.amountMinor, 12050);
      expect(BanglaNumberParser.parseFirstAmount('১২০.৫০')?.amountMinor, 12050);
    });

    test('distinguishes quantities from amounts', () {
      // ২ কেজি আম ৩০০ টাকা -> amount should be 300, not 2
      final parsed = BanglaNumberParser.parseFirstAmount('২ কেজি আম 300 টাকা');
      expect(parsed?.amountMinor, 30000);
    });
  });

  group('Multi-transaction Splitting', () {
    test('splits sentences with multiple amounts', () {
      final text = 'ভাত 120 , রিকশা 40';
      final splits = SentenceSplitter.splitSentence(text);
      expect(splits.length, 2);
      expect(splits[0], contains('120'));
      expect(splits[1], contains('40'));
    });

    test('keeps single transaction if only one amount', () {
      final text = 'বাজার করেছি এবং ডিম কিনেছি 150 টাকা';
      final splits = SentenceSplitter.splitSentence(text);
      expect(splits.length, 1);
    });
  });

  group('Full Rule Parser', () {
    final fixedClock = FixedClock(DateTime(2026, 11, 14, 15, 0));
    final matcher = CategoryMatcher([
      CategoryKeywordEntry(keyword: 'ভাত', categoryId: 'cat_food', subcategoryId: 'sub_food_lunch'),
      CategoryKeywordEntry(keyword: 'রিকশা', categoryId: 'cat_transport', subcategoryId: 'sub_trans_rickshaw'),
      CategoryKeywordEntry(keyword: 'বেতন', categoryId: 'cat_income', subcategoryId: 'sub_inc_salary'),
      CategoryKeywordEntry(keyword: 'ওষুধ', categoryId: 'cat_health', subcategoryId: 'sub_health_medicine'),
    ]);
    final parser = RuleParser(clock: fixedClock, categoryMatcher: matcher);

    test('parses single expense utterance', () {
      final drafts = parser.parse('আজকে দুপুরে ১২০ টাকা দিয়ে ভাত খেয়েছি');
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.type, 'expense');
      expect(d.amountMinor, 12000);
      expect(d.categoryId, 'cat_food');
      expect(d.subcategoryId, 'sub_food_lunch');
      expect(d.localDate, '2026-11-14');
      expect(d.confidence, greaterThanOrEqualTo(0.80));
    });

    test('parses multi-item sentence', () {
      final drafts = parser.parse('ভাত ১২০, রিকশা ৪০');
      expect(drafts.length, 2);
      expect(drafts[0].amountMinor, 12000);
      expect(drafts[0].categoryId, 'cat_food');
      expect(drafts[1].amountMinor, 4000);
      expect(drafts[1].categoryId, 'cat_transport');
    });

    test('parses income utterance', () {
      final drafts = parser.parse('অফিস থেকে বেতন পেয়েছি ৫০ হাজার টাকা');
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.type, 'income');
      expect(d.amountMinor, 5000000);
      expect(d.categoryId, 'cat_income');
    });

    test('parses relative date yesterday', () {
      final drafts = parser.parse('গতকাল ওষুধ কিনেছি ৫০০ টাকা');
      expect(drafts.length, 1);
      final d = drafts.first;
      expect(d.localDate, '2026-11-13');
      expect(d.amountMinor, 50000);
      expect(d.categoryId, 'cat_health');
    });
  });
}
