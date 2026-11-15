import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/result/result.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../parsing/normalizer.dart';
import '../../parsing/rule_parser.dart';
import '../db/app_database.dart';

class DriftTransactionRepository implements TransactionRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  DriftTransactionRepository(this.db);

  static String computeDedupHash({
    required String type,
    required int amountMinor,
    required String localDate,
    required String description,
    required String accountId,
  }) {
    final normDesc = Normalizer.normalize(description);
    final raw = '$type|$amountMinor|$localDate|$normDesc|$accountId';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  @override
  Future<Result<String, String>> saveTransaction(
    DraftTransaction draft, {
    bool allowDuplicate = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hash = computeDedupHash(
      type: draft.type,
      amountMinor: draft.amountMinor,
      localDate: draft.localDate,
      description: draft.description,
      accountId: draft.accountId,
    );

    // 1. Check for duplicates created within the last 10 minutes (600,000 ms)
    if (!allowDuplicate) {
      final tenMinutesAgo = now - 600000;
      final existing = await (db.select(db.transactions)
            ..where((tbl) =>
                tbl.dedupHash.equals(hash) &
                tbl.deletedAt.isNull() &
                tbl.createdAt.isBiggerOrEqualValue(tenMinutesAgo)))
          .get();

      if (existing.isNotEmpty) {
        return const Failure('DUPLICATE_DETECTED');
      }
    }

    final id = _uuid.v7();

    await db.transaction(() async {
      // Insert Transaction
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: id,
              type: draft.type,
              amountMinor: draft.amountMinor,
              currency: Value(draft.currency),
              description: Value(draft.description),
              itemTag: Value(draft.itemTag),
              categoryId: Value(draft.categoryId),
              accountId: draft.accountId,
              counterparty: Value(draft.counterparty),
              occurredAt: draft.occurredAtUtc,
              localDate: draft.localDate,
              source: draft.source,
              confidence: Value(draft.confidence),
              sourceText: Value(draft.sourceText),
              dedupHash: hash,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert tags
      for (final tag in draft.spendingNature) {
        await db.into(db.transactionTags).insert(
              TransactionTagsCompanion.insert(
                transactionId: id,
                tag: tag,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      // Insert Audit entry
      await db.into(db.transactionAudit).insert(
            TransactionAuditCompanion.insert(
              id: _uuid.v7(),
              transactionId: id,
              action: 'create',
              afterJson: Value(jsonEncode({
                'amount': draft.amountMinor,
                'desc': draft.description,
                'type': draft.type,
                'cat': draft.categoryId,
              })),
              at: now,
            ),
          );
    });

    return Success(id);
  }

  @override
  Future<Result<void, String>> updateTransaction(TransactionEntry tx) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await (db.select(db.transactions)..where((tbl) => tbl.id.equals(tx.id))).getSingleOrNull();
    if (current == null) return const Failure('Transaction not found');

    await db.transaction(() async {
      await db.update(db.transactions).replace(
            tx.copyWith(updatedAt: now),
          );

      // Audit row
      await db.into(db.transactionAudit).insert(
            TransactionAuditCompanion.insert(
              id: _uuid.v7(),
              transactionId: tx.id,
              action: 'update',
              beforeJson: Value(jsonEncode(current.toJson())),
              afterJson: Value(jsonEncode(tx.toJson())),
              at: now,
            ),
          );
    });

    return const Success(null);
  }

  @override
  Future<Result<void, String>> deleteTransaction(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await (db.select(db.transactions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (current == null) return const Failure('Transaction not found');

    await db.transaction(() async {
      await (db.update(db.transactions)..where((tbl) => tbl.id.equals(id))).write(
        TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );

      await db.into(db.transactionAudit).insert(
            TransactionAuditCompanion.insert(
              id: _uuid.v7(),
              transactionId: id,
              action: 'delete',
              beforeJson: Value(jsonEncode(current.toJson())),
              at: now,
            ),
          );
    });

    return const Success(null);
  }

  @override
  Future<Result<void, String>> restoreTransaction(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await (db.update(db.transactions)..where((tbl) => tbl.id.equals(id))).write(
        TransactionsCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
      );

      await db.into(db.transactionAudit).insert(
            TransactionAuditCompanion.insert(
              id: _uuid.v7(),
              transactionId: id,
              action: 'restore',
              at: now,
            ),
          );
    });

    return const Success(null);
  }

  @override
  Stream<List<TransactionWithDetails>> watchTransactions({
    String? type,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    String? fromDate,
    String? toDate,
  }) {
    final query = db.select(db.transactions).join([
      leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
      leftOuterJoin(db.accounts, db.accounts.id.equalsExp(db.transactions.accountId)),
    ]);

    query.where(db.transactions.deletedAt.isNull());

    if (type != null && type.isNotEmpty && type != 'all') {
      query.where(db.transactions.type.equals(type));
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query.where(db.transactions.categoryId.equals(categoryId));
    }
    if (accountId != null && accountId.isNotEmpty && accountId != 'all') {
      query.where(db.transactions.accountId.equals(accountId));
    }
    if (fromDate != null && toDate != null) {
      query.where(db.transactions.localDate.isBetweenValues(fromDate, toDate));
    } else if (fromDate != null) {
      query.where(db.transactions.localDate.isBiggerOrEqualValue(fromDate));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query.where(db.transactions.description.contains(searchQuery.trim()));
    }

    query.orderBy([OrderingTerm.desc(db.transactions.occurredAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(db.transactions),
          category: row.readTableOrNull(db.categories),
          account: row.readTableOrNull(db.accounts),
        );
      }).toList();
    });
  }

  @override
  Future<List<TransactionWithDetails>> getTransactions({
    String? type,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    String? fromDate,
    String? toDate,
  }) async {
    final query = db.select(db.transactions).join([
      leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
      leftOuterJoin(db.accounts, db.accounts.id.equalsExp(db.transactions.accountId)),
    ]);

    query.where(db.transactions.deletedAt.isNull());

    if (type != null && type.isNotEmpty && type != 'all') {
      query.where(db.transactions.type.equals(type));
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query.where(db.transactions.categoryId.equals(categoryId));
    }
    if (accountId != null && accountId.isNotEmpty && accountId != 'all') {
      query.where(db.transactions.accountId.equals(accountId));
    }
    if (fromDate != null && toDate != null) {
      query.where(db.transactions.localDate.isBetweenValues(fromDate, toDate));
    } else if (fromDate != null) {
      query.where(db.transactions.localDate.isBiggerOrEqualValue(fromDate));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query.where(db.transactions.description.contains(searchQuery.trim()));
    }

    query.orderBy([OrderingTerm.desc(db.transactions.occurredAt)]);

    final rows = await query.get();
    return rows.map((row) {
      return TransactionWithDetails(
        transaction: row.readTable(db.transactions),
        category: row.readTableOrNull(db.categories),
        account: row.readTableOrNull(db.accounts),
      );
    }).toList();
  }

  @override
  Future<TransactionWithDetails?> getTransactionById(String id) async {
    final query = db.select(db.transactions).join([
      leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
      leftOuterJoin(db.accounts, db.accounts.id.equalsExp(db.transactions.accountId)),
    ])..where(db.transactions.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    return TransactionWithDetails(
      transaction: row.readTable(db.transactions),
      category: row.readTableOrNull(db.categories),
      account: row.readTableOrNull(db.accounts),
    );
  }
}
