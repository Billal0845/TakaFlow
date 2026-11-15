import '../../core/result/result.dart';
import '../../parsing/rule_parser.dart';
import '../../data/db/app_database.dart';

abstract class TransactionRepository {
  Future<Result<String, String>> saveTransaction(
    DraftTransaction draft, {
    bool allowDuplicate = false,
  });

  Future<Result<void, String>> updateTransaction(TransactionEntry tx);

  Future<Result<void, String>> deleteTransaction(String id);

  Future<Result<void, String>> restoreTransaction(String id);

  Stream<List<TransactionWithDetails>> watchTransactions({
    String? type,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    String? fromDate,
    String? toDate,
  });

  Future<List<TransactionWithDetails>> getTransactions({
    String? type,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    String? fromDate,
    String? toDate,
  });

  Future<TransactionWithDetails?> getTransactionById(String id);
}

class TransactionWithDetails {
  final TransactionEntry transaction;
  final CategoryEntry? category;
  final AccountEntry? account;
  final List<String> tags;

  TransactionWithDetails({
    required this.transaction,
    this.category,
    this.account,
    this.tags = const [],
  });
}
