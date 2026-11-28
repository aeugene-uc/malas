import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/transaction_repository.dart';
import '../../model/draft.dart';
import '../../model/transaction.dart';
import '../../viewmodel/catatan_view_model.dart';
import '../draft/draft_view.dart';
import '../format.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';
import 'catatan_view.dart';

/// What closes the sheet to open the draft screen.
enum _DraftChoice { ubah, ulangi, retur }

/// One entry's lines and payments (§5.3, DESIGN.md F2), with Ubah, Ulangi,
/// Retur and Hapus. Ubah, Ulangi and Retur close the sheet with their choice,
/// and the draft opens on Catatan, since the sheet's context goes with it.
Future<void> showEntryDetail(
  BuildContext context,
  Transaction transaction,
) async {
  final viewModel = context.read<CatatanViewModel>();
  final choice = await showModalBottomSheet<_DraftChoice>(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
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
    final (tone, icon) = toneFor(transaction);
    final title = _entryTitle(transaction);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CategoryBand(tone: tone, icon: icon),
          Padding(
            padding: EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s12,
              MalasSpace.screen,
              MalasSpace.s20 + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MalasText.titleScreen,
                          ),
                          const SizedBox(height: MalasSpace.s4),
                          Text(
                            _formatDetailDate(transaction.businessDate),
                            style: MalasText.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MalasSpace.s12),
                    MoneyText.forEntry(transaction, size: MoneySize.large),
                  ],
                ),
                const SizedBox(height: MalasSpace.s20),
                _DetailsCard(
                  transaction: transaction,
                  onShowHistory: () => _showHistory(context),
                ),
                const SizedBox(height: MalasSpace.s20),
                LipButton(
                  label: 'Ubah',
                  onPressed: () =>
                      Navigator.of(context).pop(_DraftChoice.ubah),
                ),
                const SizedBox(height: MalasSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: LipButton(
                        label: 'Ulangi',
                        variant: LipVariant.secondary,
                        isSmall: true,
                        onPressed: () =>
                            Navigator.of(context).pop(_DraftChoice.ulangi),
                      ),
                    ),
                    if (_isReturnable(transaction)) ...[
                      const SizedBox(width: MalasSpace.s8),
                      Expanded(
                        child: LipButton(
                          label: 'Retur',
                          variant: LipVariant.secondary,
                          isSmall: true,
                          onPressed: () =>
                              Navigator.of(context).pop(_DraftChoice.retur),
                        ),
                      ),
                    ],
                    const SizedBox(width: MalasSpace.s8),
                    Expanded(
                      child: LipButton(
                        label: 'Hapus',
                        variant: LipVariant.danger,
                        isSmall: true,
                        onPressed: () => _delete(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        child: Padding(
          padding: const EdgeInsets.only(
            top: MalasSpace.s12,
            bottom: MalasSpace.s20,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MalasSpace.screen,
                  MalasSpace.s16,
                  MalasSpace.screen,
                  MalasSpace.s8,
                ),
                child: Text('Riwayat', style: MalasText.titleSection),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MalasSpace.screen,
                  ),
                  child: RowsCard(
                    rows: [
                      for (final record in history)
                        _HistoryRow(record: record),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

/// DESIGN.md §5.3: 140px band in the category's soft tone, base wave, white
/// ground wave, bubbles in the upper-right, handle, and 72px tile at (20, 70).
class _CategoryBand extends StatelessWidget {
  const _CategoryBand({required this.tone, required this.icon});

  final CategoryTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tileTop + _largeTileSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _CategoryBandPainter(tone: tone)),
            ),
          ),
          Positioned(
            top: MalasSpace.s12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: _handleWidth,
                height: _handleHeight,
                decoration: BoxDecoration(
                  color: MalasColors.bgSurface,
                  borderRadius: BorderRadius.circular(MalasRadius.xs),
                ),
              ),
            ),
          ),
          Positioned(
            left: MalasSpace.screen,
            top: _tileTop,
            child: Container(
              width: _largeTileSize,
              height: _largeTileSize,
              decoration: BoxDecoration(
                color: tone.base,
                borderRadius: BorderRadius.circular(MalasRadius.largeTile),
                border: Border.all(
                  color: MalasColors.bgSurface,
                  width: MalasSize.lip,
                ),
              ),
              child: Icon(
                icon,
                size: _largeTileIconSize,
                color: MalasColors.iconOnInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBandPainter extends CustomPainter {
  const _CategoryBandPainter({required this.tone});

  final CategoryTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _bandHeight),
      Paint()..color = tone.soft,
    );

    // Upper-right solid bubbles (6-26px diameter) mixing white and base tone.
    void bubble(double cx, double cy, double diameter, Color color) {
      canvas.drawCircle(
        Offset(cx * sx, cy),
        diameter / 2,
        Paint()..color = color,
      );
    }

    bubble(128, 30, 6, tone.base);
    bubble(150, 52, 14, MalasColors.bgSurface);
    bubble(216, 86, 8, tone.base);
    bubble(250, 38, 18, MalasColors.bgSurface);
    bubble(312, 28, 26, tone.base);

    // Base wave starting around y = 96.
    final baseWave = Path()
      ..moveTo(0, 100)
      ..cubicTo(90 * sx, 82, 170 * sx, 114, 245 * sx, 96)
      ..cubicTo(295 * sx, 86, 330 * sx, 102, size.width, 94)
      ..lineTo(size.width, _bandHeight)
      ..lineTo(0, _bandHeight)
      ..close();
    canvas.drawPath(baseWave, Paint()..color = tone.base);

    // Ground wave in bg/surface starting around y = 122.
    final groundWave = Path()
      ..moveTo(0, 124)
      ..cubicTo(95 * sx, 112, 180 * sx, 134, 260 * sx, 120)
      ..cubicTo(310 * sx, 112, 340 * sx, 124, size.width, 118)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(groundWave, Paint()..color = MalasColors.bgSurface);
  }

  @override
  bool shouldRepaint(_CategoryBandPainter oldDelegate) =>
      oldDelegate.tone != tone;
}

/// DESIGN.md §3 flat details card: 52px label/value rows separated by 2px
/// dividers.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.transaction, required this.onShowHistory});

  final Transaction transaction;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      ..._buildLineRows(transaction),
      if (transaction.person case final person?)
        _DetailRow(label: 'Orang', value: Text(person.name)),
      if (transaction.isKembalikan) ...[
        _DetailRow(label: 'Dibayar', value: _amountText(transaction.paid)),
        _DetailRow(
          label: 'Kembalikan',
          value: _amountText(-transaction.remaining),
        ),
      ] else if (!transaction.isFullyPaid) ...[
        _DetailRow(label: 'Dibayar', value: _amountText(transaction.paid)),
        _DetailRow(label: 'Sisa', value: _amountText(transaction.remaining)),
      ] else
        const _DetailRow(
          label: 'Dibayar',
          value: TagChip('Lunas', tone: TagTone.lunas),
        ),
      if (transaction.dueDate case final dueDate?)
        _DetailRow(label: 'Jatuh tempo', value: Text(formatEntryDate(dueDate))),
      if (transaction.hasRetur)
        const _DetailRow(label: 'Retur', value: TagChip('Ada retur')),
      if (transaction.editCount > 0)
        _DetailRow(
          label: 'Riwayat',
          onTap: onShowHistory,
          value: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MalasSpace.s8,
            runSpacing: MalasSpace.s4,
            children: [
              TagChip('Diubah ${transaction.editCount}x'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lihat',
                    style: MalasText.labelChip.copyWith(
                      color: MalasColors.textBrandDark,
                    ),
                  ),
                  const SizedBox(width: MalasSpace.s4),
                  const Icon(
                    MalasIcons.caretRight,
                    size: _rowIconSize,
                    color: MalasColors.textBrandDark,
                  ),
                ],
              ),
            ],
          ),
        ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              const Divider(
                indent: MalasSpace.s16,
                endIndent: MalasSpace.s16,
              ),
            row,
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLineRows(Transaction transaction) {
    final lines = transaction.lines;
    if (lines.isEmpty) {
      return [
        _DetailRow(label: 'Total', value: MoneyText.forEntry(transaction)),
      ];
    }
    if (lines.length == 1) {
      return [
        _DetailRow(
          label: 'Total',
          value: _buildSingleLineValue(lines.single),
        ),
      ];
    }
    return [
      for (final line in lines)
        _DetailRow(label: _lineName(line), value: _amountText(line.lineTotal)),
      _DetailRow(label: 'Total', value: MoneyText.forEntry(transaction)),
    ];
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final EditRecord record;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MalasSize.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MalasSpace.s16,
          vertical: MalasSpace.s12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatEntryDate(record.previousBusinessDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MalasText.titleItem,
                  ),
                  const SizedBox(height: MalasSpace.s4),
                  Text(
                    _formatEditTime(record.at),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MalasText.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: MalasSpace.s12),
            _amountText(record.previousTotal),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onTap});

  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _detailRowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MalasSpace.s16,
          vertical: MalasSpace.s12,
        ),
        child: Row(
          children: [
            Text(label, style: MalasText.bodySecondary),
            const SizedBox(width: MalasSpace.s12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: DefaultTextStyle.merge(
                  style: MalasText.bodyStrong,
                  textAlign: TextAlign.end,
                  child: value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

String _entryTitle(Transaction entry) {
  final names = [
    for (final line in entry.lines) line.item?.name ?? line.category?.name ?? '',
  ].where((name) => name.isNotEmpty);
  if (names.isNotEmpty) return names.join(', ');
  return entry.person?.name ?? 'Tanpa nama';
}

Widget _amountText(int amount) => MoneyText(
  amount.abs(),
  sign: amount < 0 ? MoneySign.keluar : MoneySign.neutral,
);

Widget _buildSingleLineValue(TransactionLine line) {
  final quantity = line.quantity;
  if (quantity == null) return _amountText(line.lineTotal);
  final qtyText = [quantity, ?line.unit].join(' ');
  final unitPrice = line.unitPrice;
  return Wrap(
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: MalasSpace.s4,
    children: [
      Text(unitPrice != null ? '$qtyText ×' : '$qtyText ·'),
      _amountText(unitPrice ?? line.lineTotal),
    ],
  );
}

/// DESIGN.md §8: "Rabu, 25 Nov" in detail.
String _formatDetailDate(String businessDate) {
  final date = DateTime.parse(businessDate);
  final weekday = _weekdayFullNames[date.weekday - DateTime.monday];
  final month = _monthShortNames[date.month - 1];
  return '$weekday, ${date.day} $month';
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

const _weekdayFullNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _monthShortNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const _bandHeight = 140.0;
const _tileTop = 70.0;
const _largeTileSize = 72.0;
const _largeTileIconSize = 32.0;
const _handleWidth = 40.0;
const _handleHeight = 5.0;
const _detailRowHeight = 52.0;
const _rowIconSize = 20.0;
