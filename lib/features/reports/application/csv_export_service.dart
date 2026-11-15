import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/repositories/transaction_repository.dart';

class CsvExportService {
  /// Exports transactions to CSV with UTF-8 BOM so Excel opens Bangla characters flawlessly.
  static Future<String> generateCsv(List<TransactionWithDetails> list) async {
    final rows = <List<dynamic>>[];

    // Header row
    rows.add([
      'Date',
      'Type',
      'Amount',
      'Currency',
      'Category',
      'Subcategory',
      'Description',
      'Account',
      'Counterparty',
      'Tags',
      'ID',
    ]);

    for (final item in list) {
      final tx = item.transaction;
      final cat = item.category;
      final acc = item.account;

      rows.add([
        tx.localDate,
        tx.type,
        (tx.amountMinor / 100.0).toStringAsFixed(2),
        tx.currency,
        cat?.parentId != null ? '' : (cat?.nameBn ?? cat?.nameEn ?? ''),
        cat?.parentId != null ? (cat?.nameBn ?? cat?.nameEn ?? '') : '',
        tx.description,
        acc?.name ?? tx.accountId,
        tx.counterparty ?? '',
        item.tags.join('; '),
        tx.id,
      ]);
    }

    final csvContent = const ListToCsvConverter().convert(rows);

    // UTF-8 BOM: \uFEFF
    const bom = '\uFEFF';
    return '$bom$csvContent';
  }

  static Future<void> exportAndShare(List<TransactionWithDetails> list) async {
    final csvString = await generateCsv(list);
    final bytes = utf8.encode(csvString);
    final filename = 'SelfAccountant_Export_${DateTime.now().millisecondsSinceEpoch}.csv';

    final xfile = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'text/csv',
      name: filename,
    );
    await Share.shareXFiles([xfile], text: 'SelfAccountant Transactions CSV');
  }
}
