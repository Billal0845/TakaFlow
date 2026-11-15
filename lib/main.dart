import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/main_nav_screen.dart';
import 'app/providers.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Run seeding asynchronously in the background so app launches immediately
  container.read(seedServiceProvider).seedIfNeeded().catchError((e, st) {
    debugPrint('Initial seeding notice: $e\n$st');
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SelfAccountantApp(),
    ),
  );
}

class SelfAccountantApp extends ConsumerWidget {
  const SelfAccountantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'TakaFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: Locale(settings.locale),
      supportedLocales: const [
        Locale('bn', 'BD'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainNavScreen(),
    );
  }
}
