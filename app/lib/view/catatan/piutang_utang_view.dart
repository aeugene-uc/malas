import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/api_client.dart';
import '../../data/transaction_repository.dart';
import '../../model/transaction.dart';
import '../../viewmodel/piutang_utang_view_model.dart';
import '../format.dart';
import 'catatan_view.dart' show formatEntryDate;

/// Piutang and Utang (§7.4), from Catatan or Beranda's card.
class PiutangUtangView extends StatelessWidget {
  const PiutangUtangView({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const PiutangUtangView());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PiutangUtangViewModel(
        transactionRepository: TransactionRepository(context.read<ApiClient>()),
      )..load(),
      child: const _PiutangUtangScreen(),
    );
  }
}

class _PiutangUtangScreen extends StatelessWidget {
  const _PiutangUtangScreen();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PiutangUtangViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Piutang/Utang'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Piutang ${formatRupiah(viewModel.piutangTotal)}'),
              Tab(text: 'Utang ${formatRupiah(viewModel.utangTotal)}'),
            ],
          ),
        ),
        body: switch (viewModel) {
          PiutangUtangViewModel(isLoading: true) => const Center(
            child: CircularProgressIndicator(),
          ),
          PiutangUtangViewModel(
            errorMessage: final message?,
            piutang: [],
            utang: [],
          ) =>
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: viewModel.load,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          _ => TabBarView(
            children: [
              _OpenList(transactions: viewModel.piutang, isPiutang: true),
              _OpenList(transactions: viewModel.utang, isPiutang: false),
            ],
          ),
        },
      ),
    );
  }
}

class _OpenList extends StatelessWidget {
  const _OpenList({required this.transactions, required this.isPiutang});

  final List<Transaction> transactions;
  final bool isPiutang;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(isPiutang ? 'Tidak ada piutang' : 'Tidak ada utang'),
      );
    }
    return ListView(
      children: [
        for (final transaction in transactions)
          _OpenTile(transaction: transaction, isPiutang: isPiutang),
      ],
    );
  }
}

class _OpenTile extends StatelessWidget {
  const _OpenTile({required this.transaction, required this.isPiutang});

  final Transaction transaction;
  final bool isPiutang;

  @override
  Widget build(BuildContext context) {
    final personName = transaction.person?.name ?? 'Tanpa nama';
    // The person is the card's title, so the details list only the lines.
    final lineDescriptions = transaction.lines
        .map(describeLine)
        .where((description) => description.isNotEmpty)
        .join(', ');
    final details = [
      if (lineDescriptions.isNotEmpty) lineDescriptions,
      formatEntryDate(transaction.businessDate),
      if (transaction.dueDate case final dueDate?)
        'Jatuh tempo ${formatEntryDate(dueDate)}',
    ];
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    personName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  transaction.isKembalikan
                      ? 'Kembalikan ${formatRupiah(-transaction.remaining)}'
                      : formatRupiah(transaction.remaining),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Text(
              details.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPiutang)
                  TextButton(
                    onPressed: () => _remind(transaction, personName),
                    child: const Text('Ingatkan'),
                  ),
                if (!transaction.isKembalikan)
                  TextButton(
                    onPressed: () => _askPayment(context, transaction),
                    child: const Text('Bayar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The owner sends it themselves from WhatsApp (§15): the app never sends
  /// a message, and no phone number leaves the phone.
  Future<void> _remind(Transaction transaction, String personName) {
    return SharePlus.instance.share(
      ShareParams(
        text: buildReminderText(
          personName: personName,
          transaction: transaction,
        ),
      ),
    );
  }

  Future<void> _askPayment(BuildContext context, Transaction transaction) {
    final viewModel = context.read<PiutangUtangViewModel>();
    return showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: _PaymentDialog(transaction: transaction),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.transaction});

  final Transaction transaction;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amountController = TextEditingController(
    text: groupThousands(widget.transaction.remaining),
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = context.watch<PiutangUtangViewModel>().errorMessage;
    return AlertDialog(
      title: const Text('Bayar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              prefixText: 'Rp ',
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    final isPaid = await context.read<PiutangUtangViewModel>().pay(
      transaction: widget.transaction,
      amountText: _amountController.text,
    );
    if (isPaid) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

/// A polite, fixed reminder the owner can edit before sending (§15).
String buildReminderText({
  required String personName,
  required Transaction transaction,
}) {
  final dueDate = transaction.dueDate;
  final duePart = dueDate == null
      ? ''
      : ', jatuh tempo ${formatEntryDate(dueDate)}';
  return 'Halo $personName, mengingatkan sisa pembayaran '
      '${formatRupiah(transaction.remaining)} untuk catatan '
      '${formatEntryDate(transaction.businessDate)}$duePart. Terima kasih.';
}
