import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'app_database.dart';

class SeedService {
  final AppDatabase db;

  SeedService(this.db);

  static const int currentSeedVersion = 1;

  Future<void> seedIfNeeded() async {
    final setting = await (db.select(db.appSettings)
          ..where((tbl) => tbl.key.equals('seed_version')))
        .getSingleOrNull();

    final installedVersion = setting != null ? int.tryParse(setting.value) ?? 0 : 0;
    if (installedVersion >= currentSeedVersion) {
      return; // Already seeded
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Seed Default Accounts
    await db.batch((batch) {
      batch.insertAll(
        db.accounts,
        [
          AccountsCompanion.insert(
            id: 'acc_cash',
            name: 'Cash',
            kind: 'cash',
            isDefault: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'acc_bkash',
            name: 'bKash',
            kind: 'bkash',
            isDefault: const Value(0),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'acc_nagad',
            name: 'Nagad',
            kind: 'nagad',
            isDefault: const Value(0),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'acc_bank',
            name: 'Bank',
            kind: 'bank',
            isDefault: const Value(0),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'acc_card',
            name: 'Card',
            kind: 'card',
            isDefault: const Value(0),
            createdAt: now,
            updatedAt: now,
          ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });

    // 2. Seed Categories from assets/seed/categories.json
    try {
      final jsonStr = await rootBundle.loadString('assets/seed/categories.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;

      for (int i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final catId = item['id'] as String;

        await db.into(db.categories).insert(
              CategoriesCompanion.insert(
                id: catId,
                nameEn: item['name_en'] as String,
                nameBn: Value(item['name_bn'] as String?),
                kind: item['kind'] as String,
                icon: Value(item['icon'] as String?),
                color: Value(item['color'] as String?),
                isSystem: const Value(1),
                sortOrder: Value(i),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrReplace,
            );

        // Subcategories
        final subcats = item['subcategories'] as List<dynamic>? ?? [];
        for (int j = 0; j < subcats.length; j++) {
          final sub = subcats[j] as Map<String, dynamic>;
          await db.into(db.categories).insert(
                CategoriesCompanion.insert(
                  id: sub['id'] as String,
                  parentId: Value(catId),
                  nameEn: sub['name_en'] as String,
                  nameBn: Value(sub['name_bn'] as String?),
                  kind: item['kind'] as String,
                  isSystem: const Value(1),
                  sortOrder: Value(j),
                  createdAt: now,
                  updatedAt: now,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      }
    } catch (_) {
      // Fallback or test environment where rootBundle is unavailable
    }

    // 3. Seed Keywords from assets/seed/category_keywords.json
    try {
      final kwStr = await rootBundle.loadString('assets/seed/category_keywords.json');
      final kwList = jsonDecode(kwStr) as List<dynamic>;

      final companions = <CategoryKeywordsCompanion>[];
      for (int i = 0; i < kwList.length; i++) {
        final kw = kwList[i] as Map<String, dynamic>;
        final targetCatId = (kw['sub_id'] as String?) ?? (kw['category_id'] as String);
        companions.add(
          CategoryKeywordsCompanion.insert(
            id: 'seed_kw_$i',
            categoryId: targetCatId,
            keyword: (kw['keyword'] as String).toLowerCase(),
            weight: Value((kw['weight'] as num?)?.toDouble() ?? 1.0),
            source: 'seed',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      await db.batch((batch) {
        batch.insertAll(db.categoryKeywords, companions, mode: InsertMode.insertOrReplace);
      });
    } catch (_) {
      // Fallback or test environment
    }

    // 4. Update seed version
    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(
            key: 'seed_version',
            value: currentSeedVersion.toString(),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
