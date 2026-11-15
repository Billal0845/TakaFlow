import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_accountant/app/providers.dart';
import 'package:self_accountant/data/db/app_database.dart';
import 'package:self_accountant/main.dart';

void main() {
  testWidgets('SelfAccountantApp launches and displays main navigation tabs',
      (WidgetTester tester) async {
    final memoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
        ],
        child: const SelfAccountantApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify presence of navigation items
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('লেনদেন'), findsOneWidget);
    expect(find.text('রিপোর্ট'), findsOneWidget);
    expect(find.text('সেটিংস'), findsOneWidget);

    await memoryDb.close();
  });
}
