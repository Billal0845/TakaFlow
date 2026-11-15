class AppStrings {
  final String locale;

  const AppStrings(this.locale);

  bool get isBn => locale == 'bn';

  String get appTitle => isBn ? 'টাকাফ্লো' : 'TakaFlow';
  String get home => isBn ? 'হোম' : 'Home';
  String get transactions => isBn ? 'লেনদেন' : 'Transactions';
  String get reports => isBn ? 'রিপোর্ট' : 'Reports';
  String get settings => isBn ? 'সেটিংস' : 'Settings';

  // Home Screen
  String get todaySpending => isBn ? 'আজকের খরচ' : "Today's Expense";
  String get monthSpending => isBn ? 'চলতি মাস' : 'This Month';
  String get recentTransactions => isBn ? 'সাম্প্রতিক লেনদেন' : 'Recent Transactions';
  String get viewAll => isBn ? 'সব দেখুন' : 'View All';
  String get tapToSpeak => isBn ? 'মুখে বলুন' : 'Tap to Speak';
  String get listening => isBn ? 'শুনছি...' : 'Listening...';
  String get typeSentenceHint => isBn ? 'যেমন: দুপুরে ১২০ টাকা ভাত খেয়েছি' : 'e.g. Lunch 120 taka';
  String get addTransaction => isBn ? 'যোগ করুন' : 'Add Transaction';
  String get manualEntry => isBn ? 'ফর্ম পূরণ' : 'Manual Form';

  // Preview Screen
  String get previewTitle => isBn ? 'যাচাই করুন' : 'Review Draft';
  String get amount => isBn ? 'পরিমাণ' : 'Amount';
  String get description => isBn ? 'বিবরণ' : 'Description';
  String get category => isBn ? 'ক্যাটেগরি' : 'Category';
  String get account => isBn ? 'অ্যাকাউন্ট' : 'Account';
  String get date => isBn ? 'তারিখ' : 'Date';
  String get confirmSave => isBn ? 'সংরক্ষণ করুন' : 'Confirm & Save';
  String get discard => isBn ? 'বাতিল' : 'Discard';
  String get savedSuccess => isBn ? 'লেনদেন সংরক্ষিত হয়েছে' : 'Transaction saved';
  String get undo => isBn ? 'পূর্বাবস্থায় আনুন' : 'Undo';
  String get duplicateWarning => isBn ? 'অনুরূপ লেনদেন ইতিমধ্যে বিদ্যমান' : 'Duplicate transaction detected';
  String get saveAnyway => isBn ? 'তবুও সংরক্ষণ' : 'Save Anyway';

  // Types
  String typeLabel(String type) => switch (type) {
        'expense' => isBn ? 'খরচ' : 'Expense',
        'income' => isBn ? 'আয়' : 'Income',
        'transfer' => isBn ? 'স্থানান্তর' : 'Transfer',
        'refund' => isBn ? 'রিফান্ড' : 'Refund',
        'loan_given' => isBn ? 'ধার দেওয়া' : 'Loan Given',
        'loan_received' => isBn ? 'ধার গ্রহণ' : 'Loan Received',
        'loan_repayment' => isBn ? 'ধার পরিশোধ' : 'Repayment',
        _ => type,
      };

  // Reports
  String get periodDaily => isBn ? 'দৈনিক' : 'Daily';
  String get periodWeekly => isBn ? 'সাপ্তাহিক' : 'Weekly';
  String get periodMonthly => isBn ? 'মাসিক' : 'Monthly';
  String get totalIncome => isBn ? 'মোট আয়' : 'Total Income';
  String get totalExpense => isBn ? 'মোট খরচ' : 'Total Expense';
  String get netSavings => isBn ? 'নিট সঞ্চয়' : 'Net Savings';
  String get categoryBreakdown => isBn ? 'খাতভিত্তিক ব্যয়' : 'Category Breakdown';
  String get dailyTrend => isBn ? 'দৈনিক খরচের ধারা' : 'Daily Trend';
  String get exportCsv => isBn ? 'CSV এক্সপোর্ট' : 'Export CSV';

  // Settings
  String get language => isBn ? 'ভাষা' : 'Language';
  String get bangla => 'বাংলা';
  String get english => 'English';
  String get digitStyle => isBn ? 'সংখ্যার ধরন' : 'Digit Style';
  String get banglaDigits => isBn ? 'বাংলা (০-৯)' : 'Bengali (০-৯)';
  String get englishDigits => isBn ? 'ইংরেজি (0-9)' : 'English (0-9)';
  String get defaultAccount => isBn ? 'ডিফল্ট অ্যাকাউন্ট' : 'Default Account';
  String get about => isBn ? 'অ্যাপ সম্পর্কে' : 'About';
  String get version => isBn ? 'ভার্সন' : 'Version';
}
