import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/transaction_repository.dart';
import '../../model/draft.dart';
import '../../model/transaction.dart';
import '../../viewmodel/catatan_view_model.dart';
import '../draft/draft_view.dart';
import '../format.dart';
import 'catatan_view.dart';

/// What closes the sheet to open the draft screen.
enum _DraftChoice { ubah, ulangi, retur }

/// One entry's lines and payments (§5.3: details behind a tap), with Ubah,
/// Ulangi, Retur and Hapus. Ubah, Ulangi and Retur close the sheet with their
/// choice, and the draft opens on Catatan, since the sheet's context goes
/// with it.
Future<void> showEntryDetail(
  BuildContext context,
  Transaction transaction,
) async {
  final viewModel = context.read<CatatanViewModel>();
  final choice = await showModalBottomSheet<_DraftChoice>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => ChangeNotifierProvider.value(
      value: viewModel,
      child: _EntryDetail(transaction: transaction),
    ),
  );
  if (choice == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (choice == _DraftChoice.ubah) {
    final businessToday = await viewModel.fetchBusinessToday();
    if (!context.mounted) return;
    if (businessToday == null) {
      messenger.showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
      return;
    }
    await openDraftScreen(
      context,
      drafts: [Draft.fromTransaction(transaction)],
      businessToday: businessToday,
      onChanged: viewModel.load,
      editingTransactionId: transaction.id,
    );
    return;
  }
  final copy = choice == _DraftChoice.ulangi
      ? EntryCopy.ulangi
      : EntryCopy.retur;
  final readResult = await viewModel.fetchCopyDraft(transaction, copy);
  if (!context.mounted) return;
  if (readResult == null) {
    messenger.showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
    return;
  }
  await openDraftScreen(
    context,
    drafts: readResult.drafts,
    warnings: readResult.warnings,
    // The server dates the copy on the store's business day.
    businessToday: readResult.drafts.first.businessDate!,
    onChanged: viewModel.load,
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
            if (transaction.editCount > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => _showHistory(context),
                  child: Text('Diubah ${transaction.editCount}x'),
                ),
              ),
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
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(context).pop(_DraftChoice.ubah),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ubah'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(_DraftChoice.ulangi),
                    icon: const Icon(Icons.replay),
                    label: const Text('Ulangi'),
                  ),
                ),
                if (_isReturnable(transaction)) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(_DraftChoice.retur),
                      icon: const Icon(Icons.undo),
                      label: const Text('Retur'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
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

  Future<void> _showHistory(BuildContext context) async {
    final viewModel = context.read<CatatanViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final history = await viewModel.fetchHistory(transaction);
    if (!context.mounted) return;
    if (history == null) {
      messenger.showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final record in history)
              ListTile(
                title: Text(formatRupiah(record.previousTotal)),
                subtitle: Text(formatEntryDate(record.previousBusinessDate)),
                trailing: Text(_formatEditTime(record.at)),
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

/// A Retur takes back lines, so a bare amount or a Retur itself has none
/// to take back.
bool _isReturnable(Transaction transaction) =>
    transaction.lines.isNotEmpty && transaction.total > 0;

/// A bare amount with no category still needs something on its row.
String _lineName(TransactionLine line) {
  final description = describeLine(line);
  return description.isEmpty ? 'Tanpa nama' : description;
}

/// When an Ubah happened, on the phone's clock: it is a moment, not a
/// business date.
String _formatEditTime(DateTime at) {
  final local = at.toLocal();
  final date = formatEntryDate(local.toIso8601String().substring(0, 10));
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
