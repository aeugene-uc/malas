import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/api_client.dart';
import '../../data/transaction_repository.dart';
import '../../model/transaction.dart';
import '../../viewmodel/piutang_utang_view_model.dart';
import '../format.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';

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

class _PiutangUtangScreen extends StatefulWidget {
  const _PiutangUtangScreen();

  @override
  State<_PiutangUtangScreen> createState() => _PiutangUtangScreenState();
}

class _PiutangUtangScreenState extends State<_PiutangUtangScreen> {
  bool _isPiutangShown = true;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PiutangUtangViewModel>();
    final total = _isPiutangShown
        ? viewModel.piutangTotal
        : viewModel.utangTotal;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BrandHeader(
            title: 'Piutang/Utang',
            height: _headerHeight,
            actions: [
              IconButton(
                tooltip: 'Tutup',
                color: MalasColors.textOnBrand,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(MalasIcons.x),
              ),
            ],
            controls: SegmentedSelector(
              labels: const ['Piutang', 'Utang'],
              values: [
                formatRupiah(viewModel.piutangTotal),
                formatRupiah(viewModel.utangTotal),
              ],
              selectedIndex: _isPiutangShown ? 0 : 1,
              isOnBrand: true,
              onSelected: (index) =>
                  setState(() => _isPiutangShown = index == 0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s16,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: switch (viewModel) {
              PiutangUtangViewModel(isLoading: true) => const _Skeleton(),
              PiutangUtangViewModel(
                errorMessage: final message?,
                piutang: [],
                utang: [],
              ) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: MalasText.body,
                    ),
                    const SizedBox(height: MalasSpace.s16),
                    LipButton(label: 'Coba lagi', onPressed: viewModel.load),
                  ],
                ),
              _ => _OpenList(
                transactions: _isPiutangShown
                    ? viewModel.piutang
                    : viewModel.utang,
                total: total,
                isPiutang: _isPiutangShown,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// §4.3: skeleton blocks at row size instead of a spinner.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _skeletonRowCount; index++)
          Container(
            height: MalasSize.row,
            margin: const EdgeInsets.only(bottom: MalasSpace.s12),
            decoration: BoxDecoration(
              color: MalasColors.bgSkeleton,
              borderRadius: BorderRadius.circular(MalasRadius.lg),
            ),
          ),
      ],
    );
  }
}

class _OpenList extends StatelessWidget {
  const _OpenList({
    required this.transactions,
    required this.total,
    required this.isPiutang,
  });

  final List<Transaction> transactions;
  final int total;
  final bool isPiutang;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Text(
        isPiutang ? 'Tidak ada piutang' : 'Tidak ada utang',
        textAlign: TextAlign.center,
        style: MalasText.body,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: isPiutang ? 'Piutang' : 'Utang',
          trailing: MoneyText(total),
        ),
        RowsCard(
          rows: [
            for (final transaction in transactions)
              _OpenRow(transaction: transaction, isPiutang: isPiutang),
          ],
        ),
      ],
    );
  }
}

/// A §3 row for one person, with Ingatkan and Bayar right-aligned below it.
class _OpenRow extends StatelessWidget {
  const _OpenRow({required this.transaction, required this.isPiutang});

  final Transaction transaction;
  final bool isPiutang;

  @override
  Widget build(BuildContext context) {
    final personName = transaction.person?.name ?? 'Tanpa nama';
    final dueDate = transaction.dueDate;
    final meta = dueDate != null
        ? 'Jatuh tempo ${formatEntryDate(dueDate)}'
        : formatEntryDate(transaction.businessDate);
    final canRemind = isPiutang;
    final canPay = !transaction.isKembalikan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MalasSpace.s16,
        MalasSpace.s16,
        MalasSpace.s16,
        MalasSpace.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryTile(
                tone: isPiutang ? CategoryTone.minuman : CategoryTone.jeruk,
                icon: isPiutang
                    ? MalasIcons.usersThreeFill
                    : MalasIcons.handCoinsFill,
              ),
              const SizedBox(width: MalasSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            personName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MalasText.titleItem,
                          ),
                        ),
                        const SizedBox(width: MalasSpace.s12),
                        MoneyText(transaction.remaining.abs()),
                      ],
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MalasText.bodySecondary,
                    ),
                    if (transaction.isKembalikan) ...[
                      const SizedBox(height: MalasSpace.s4),
                      const TagChip('Kembalikan', tone: TagTone.perhatian),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canRemind || canPay) ...[
            const SizedBox(height: MalasSpace.s12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canRemind)
                  TextButton(
                    onPressed: () => _remind(transaction, personName),
                    child: const Text('Ingatkan'),
                  ),
                if (canRemind && canPay) const SizedBox(width: MalasSpace.s12),
                if (canPay)
                  LipButton(
                    label: 'Bayar',
                    isSmall: true,
                    onPressed: () => _askPayment(context, transaction),
                  ),
              ],
            ),
          ],
        ],
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

  /// DESIGN §4.2: a sheet instead of a dialog.
  Future<void> _askPayment(BuildContext context, Transaction transaction) {
    final viewModel = context.read<PiutangUtangViewModel>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: _PaymentSheet(transaction: transaction),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.transaction});

  final Transaction transaction;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
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
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MalasSpace.screen,
          MalasSpace.s12,
          MalasSpace.screen,
          MalasSpace.s20 + keyboardHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _handleWidth,
                height: _handleHeight,
                decoration: BoxDecoration(
                  color: MalasColors.borderCard,
                  borderRadius: BorderRadius.circular(MalasRadius.xs),
                ),
              ),
            ),
            const SizedBox(height: MalasSpace.s20),
            Text('Bayar', style: MalasText.titleScreen),
            const SizedBox(height: MalasSpace.s16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              autofocus: true,
              style: MalasText.moneyRow,
              decoration: const InputDecoration(
                labelText: 'Jumlah',
                prefixText: 'Rp ',
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: MalasSpace.s12),
              Text(
                errorMessage,
                style: MalasText.bodySecondary.copyWith(
                  color: MalasColors.textError,
                ),
              ),
            ],
            const SizedBox(height: MalasSpace.s24),
            LipButton(label: 'Simpan', onPressed: _isSaving ? null : _save),
            const SizedBox(height: MalasSpace.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
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

/// Tall enough for the 2-line SegmentedSelector to clear the far hill (§5.1).
const _headerHeight = 200.0;
const _skeletonRowCount = 3;

/// §4.2 sheet handle.
const _handleWidth = 40.0;
const _handleHeight = 5.0;

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
