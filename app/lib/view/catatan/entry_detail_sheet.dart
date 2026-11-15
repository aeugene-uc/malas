import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/transaction.dart';
import '../../viewmodel/catatan_view_model.dart';
import '../format.dart';
import 'catatan_view.dart';

/// One entry's lines and payments (§5.3: details behind a tap). Edit, Ulangi
/// and Retur join Hapus once the draft screen (F3) exists.
Future<void> showEntryDetail(BuildContext context, Transaction transaction) {
  final viewModel = context.read<CatatanViewModel>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => ChangeNotifierProvider.value(
      value: viewModel,
      child: _EntryDetail(transaction: transaction),
    ),
  );
}

class _EntryDetail extends StatelessWidget {
  const _EntryDetail({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatEntryDate(transaction.businessDate),
              style: textTheme.titleMedium,
            ),
            if (transaction.person case final person?) Text(person.name),
            const SizedBox(height: 16),
            for (final line in transaction.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(_lineName(line))),
                    Text(formatRupiah(line.lineTotal)),
                  ],
                ),
              ),
            const Divider(height: 24),
            _AmountRow(label: 'Total', amount: transaction.total),
            _AmountRow(label: 'Dibayar', amount: transaction.paid),
            if (transaction.isKembalikan)
              _AmountRow(label: 'Kembalikan', amount: -transaction.remaining)
            else if (!transaction.isFullyPaid)
              _AmountRow(label: 'Sisa', amount: transaction.remaining),
            if (transaction.dueDate case final dueDate?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Jatuh tempo ${formatEntryDate(dueDate)}'),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }

  /// Everything is taken before the sheet closes, since its context goes
  /// with it.
  Future<void> _delete(BuildContext context) async {
    final viewModel = context.read<CatatanViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await deleteWithUndo(
      viewModel: viewModel,
      messenger: messenger,
      transaction: transaction,
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(formatRupiah(amount)),
        ],
      ),
    );
  }
}

/// A bare amount with no category still needs something on its row.
String _lineName(TransactionLine line) {
  final description = describeLine(line);
  return description.isEmpty ? 'Tanpa nama' : description;
}
