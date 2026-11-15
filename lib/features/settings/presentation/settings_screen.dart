import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final strings = AppStrings(settings.locale);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Setting
          Card(
            child: ListTile(
              title: Text(strings.language),
              subtitle: Text(settings.locale == 'bn' ? strings.bangla : strings.english),
              trailing: DropdownButton<String>(
                value: settings.locale,
                underline: const SizedBox(),
                dropdownColor: AppTheme.cardDark,
                items: [
                  DropdownMenuItem(value: 'bn', child: Text(strings.bangla)),
                  DropdownMenuItem(value: 'en', child: Text(strings.english)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    notifier.setLocale(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Digit Style Setting
          Card(
            child: ListTile(
              title: Text(strings.digitStyle),
              subtitle: Text(settings.useBanglaDigits ? strings.banglaDigits : strings.englishDigits),
              trailing: Switch(
                value: settings.useBanglaDigits,
                activeThumbColor: AppTheme.incomeGreen,
                onChanged: (val) {
                  notifier.setDigitStyle(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Privacy & On-device status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, size: 20, color: AppTheme.incomeGreen),
                      const SizedBox(width: 8),
                      Text(
                        strings.isBn ? 'গোপনীয়তা ও স্থানীয় সংরক্ষণ' : 'Privacy & Local Storage',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.isBn
                        ? 'আপনার সমস্ত আর্থিক তথ্য এই ডিভাইসে সম্পূর্ণ অফলাইনে সংরক্ষিত থাকে। কোনো ডাটা বাইরের সার্ভারে যায় না।'
                        : 'All financial data is stored 100% offline on your device. No data is sent to external servers.',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          Center(
            child: Text(
              '${strings.appTitle} v1.0.0',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
