import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/draft_repository.dart';
import '../../data/unsent_drafts_store.dart';
import '../../model/draft.dart';
import '../../model/transaction.dart';
import '../../viewmodel/draft_view_model.dart';
import '../format.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';

/// Opens the draft screen for what a read (Bicara, Foto) or Ketik produced.
/// After Simpan it shows the 10-second Batal toast (spec §5.2) on the
/// caller's screen. [onChanged] runs after a save and after a Batal, so the
/// caller can reload what it shows. [idempotencyKeys] and [isUnsent] reopen
/// drafts kept on the phone after a failed Simpan (#25).
Future<void> openDraftScreen(
  BuildContext context, {
  required List<Draft> drafts,
  List<ReadWarning> warnings = const [],
  required String businessToday,
  required VoidCallback onChanged,
  List<String>? idempotencyKeys,
  bool isUnsent = false,
  String? editingTransactionId,
}) async {
  final viewModel = DraftViewModel(
    draftRepository: context.read<DraftRepository>(),
    businessToday: businessToday,
    drafts: drafts,
    warnings: warnings,
    // A failed edit is retried on the screen; kept on the phone it would
    // come back as a new entry.
    unsentDraftsStore: editingTransactionId == null
        ? context.read<UnsentDraftsStore>()
        : null,
    editingTransactionId: editingTransactionId,
    idempotencyKeys: idempotencyKeys,
    isUnsent: isUnsent,
  );
  final isSaved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const DraftView(),
      ),
    ),
  );
  if (!context.mounted) return;
  if (isSaved != true) {
    viewModel.dispose();
    return;
  }
  onChanged();
  if (viewModel.isEditing) {
    // Batal deletes what Simpan made, which here is the entry itself.
    viewModel.dispose();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tersimpan')));
    return;
  }
  await showBatalToast(context, viewModel: viewModel, onChanged: onChanged);
}

/// "Tersimpan" with Batal for 10 seconds. The ViewModel stays alive until
/// the toast closes, because Batal needs it to delete what was saved.
Future<void> showBatalToast(
  BuildContext context, {
  required DraftViewModel viewModel,
  required VoidCallback onChanged,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final closedReason = await messenger
      .showSnackBar(
        SnackBar(
          content: const Text('Tersimpan'),
          duration: const Duration(seconds: 10),
          // Flutter keeps a toast with an action open until tapped otherwise.
          persist: false,
          action: SnackBarAction(label: 'Batal', onPressed: () {}),
        ),
      )
      .closed;
  if (closedReason == SnackBarClosedReason.action) {
    await viewModel.batal();
    final batalError = viewModel.errorMessage;
    if (batalError != null) {
      messenger.showSnackBar(SnackBar(content: Text(batalError)));
    }
    onChanged();
  }
  viewModel.dispose();
}

/// Spec §7.3, §8.2: every draft from one input, each line as name, quantity
/// and total. Tapping a line opens the rest. Nothing is saved before Simpan.
class DraftView extends StatelessWidget {
  const DraftView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final activeDate = viewModel.businessDate ?? viewModel.businessToday;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BrandHeader(
            title: 'Draf',
            subtitle: formatEntryDate(activeDate),
            height: _formHeaderHeight,
            // Passing an action suppresses coins so this form screen keeps
            // hills only (DESIGN.md §5.4).
            actions: [
              IconButton(
                tooltip: 'Tutup',
                color: MalasColors.textOnBrand,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(MalasIcons.x),
              ),
            ],
            controls: const _DateChips(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s8,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var draftIndex = 0;
                  draftIndex < viewModel.drafts.length;
                  draftIndex++
                )
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: draftIndex < viewModel.drafts.length - 1
                          ? MalasSpace.s24
                          : 0,
                    ),
                    child: _DraftSection(draftIndex: draftIndex),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _SimpanBar(),
    );
  }
}

class _DateChips extends StatelessWidget {
  const _DateChips();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final pickedDate = viewModel.dateChoice == DateChoice.pilihTanggal
        ? viewModel.businessDate
        : null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _OnBrandLipChip(
            label: 'Hari ini',
            isSelected: viewModel.dateChoice == DateChoice.hariIni,
            onPressed: () => viewModel.selectDate(DateChoice.hariIni),
          ),
          const SizedBox(width: MalasSpace.s8),
          _OnBrandLipChip(
            label: 'Kemarin',
            isSelected: viewModel.dateChoice == DateChoice.kemarin,
            onPressed: () => viewModel.selectDate(DateChoice.kemarin),
          ),
          const SizedBox(width: MalasSpace.s8),
          _OnBrandLipChip(
            label: pickedDate == null
                ? 'Pilih tanggal'
                : formatEntryDate(pickedDate),
            isSelected: viewModel.dateChoice == DateChoice.pilihTanggal,
            onPressed: () => _pickDate(context, viewModel),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, DraftViewModel viewModel) async {
    final today = DateTime.parse(viewModel.businessToday);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 365)),
      // A future date is rejected by the server, so it can't be picked.
      lastDate: today,
    );
    if (picked == null) return;
    viewModel.selectDate(
      DateChoice.pilihTanggal,
      pickedDate: formatBusinessDate(picked),
    );
  }
}

/// DESIGN.md §2 chip on brand: pressed violet with dark lip when idle, white
/// with deep lip when selected.
class _OnBrandLipChip extends StatelessWidget {
  const _OnBrandLipChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: LipPressable(
        onPressed: onPressed,
        fill: isSelected
            ? MalasColors.bgOnBrandAction
            : MalasColors.bgBrandPressed,
        lip: isSelected ? MalasColors.borderLip : MalasColors.decoGelap2,
        borderRadius: BorderRadius.circular(MalasRadius.chip),
        child: SizedBox(
          height: MalasSize.buttonKecil,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
            child: Center(
              child: Text(
                label,
                style: MalasText.labelChip.copyWith(
                  color: isSelected
                      ? MalasColors.textOnBrandAction
                      : MalasColors.textOnBrand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftSection extends StatelessWidget {
  const _DraftSection({required this.draftIndex});

  final int draftIndex;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final draft = viewModel.drafts[draftIndex];
    final isMasuk = draft.direction == Direction.masuk;
    final personName = draft.personName;
    final paymentTag = _paymentTag(draft);
    final draftWarnings = viewModel.warningsFor(draftIndex: draftIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: [isMasuk ? 'Masuk' : 'Keluar', ?personName].join(' · '),
          trailing: _draftMoney(draft.direction, draft.total),
        ),
        if (paymentTag != null) ...[
          Align(alignment: Alignment.centerLeft, child: paymentTag),
          const SizedBox(height: MalasSpace.s12),
        ],
        if (draftWarnings.isNotEmpty) ...[
          _WarningList(warnings: draftWarnings),
          const SizedBox(height: MalasSpace.s12),
        ],
        if (draft.lines.isNotEmpty)
          RowsCard(
            rows: [
              for (
                var lineIndex = 0;
                lineIndex < draft.lines.length;
                lineIndex++
              )
                _DraftLineRow(draftIndex: draftIndex, lineIndex: lineIndex),
            ],
          ),
      ],
    );
  }
}

/// A Retur carries no payments: the server works out on Simpan how much
/// cancels the original's open balance and how much is cash back (S6). So
/// only a draft that isn't a Retur reads Belum dibayar.
Widget? _paymentTag(Draft draft) {
  if (draft.linkedTransactionId != null) return const TagChip('Retur');
  if (draft.payments.isEmpty) {
    return const TagChip('Belum dibayar', tone: TagTone.piutang);
  }
  return null;
}

class _DraftLineRow extends StatelessWidget {
  const _DraftLineRow({required this.draftIndex, required this.lineIndex});

  final int draftIndex;
  final int lineIndex;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final draft = viewModel.drafts[draftIndex];
    final line = draft.lines[lineIndex];
    final lineTotal = line.lineTotal;
    final quantityText = describeQuantity(line);
    final (tone, icon) = _toneForDraftLine(draft.direction, line);
    final lineWarnings = viewModel.warningsFor(
      draftIndex: draftIndex,
      lineIndex: lineIndex,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntryRow(
          // A bare amount ("bon Pak Budi 30 ribu") has no item.
          title: line.itemName ?? 'Tanpa barang',
          meta: quantityText,
          money: lineTotal == null
              ? Text(
                  '—',
                  style: MalasText.moneyRow.copyWith(
                    color: MalasColors.textMeta,
                  ),
                )
              : _draftMoney(draft.direction, lineTotal),
          tone: tone,
          icon: icon,
          onTap: () => _openLineEditor(context, viewModel),
        ),
        if (lineWarnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.s16,
              0,
              MalasSpace.s16,
              MalasSpace.s12,
            ),
            child: _WarningList(warnings: lineWarnings),
          ),
      ],
    );
  }

  Future<void> _openLineEditor(
    BuildContext context,
    DraftViewModel viewModel,
  ) async {
    final line = viewModel.drafts[draftIndex].lines[lineIndex];
    final edited = await showModalBottomSheet<LineEdit>(
      context: context,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      builder: (_) => LineEditorSheet(line: line),
    );
    if (edited == null) return;
    viewModel.editLine(
      draftIndex: draftIndex,
      lineIndex: lineIndex,
      edit: edited.applyTo,
    );
  }
}

/// Flat attention card matching Beranda's _AttentionCard look (DESIGN.md §3).
class _WarningList extends StatelessWidget {
  const _WarningList({required this.warnings});

  final List<ReadWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, warning) in warnings.indexed) ...[
          if (index > 0) const SizedBox(height: MalasSpace.s8),
          Container(
            constraints: const BoxConstraints(minHeight: MalasSize.row),
            padding: const EdgeInsets.symmetric(
              horizontal: MalasSpace.s16,
              vertical: MalasSpace.s12,
            ),
            decoration: BoxDecoration(
              color: MalasColors.bgHighlight,
              borderRadius: BorderRadius.circular(MalasRadius.lg),
              border: Border.all(
                color: MalasColors.borderAttention,
                width: MalasSize.cardStroke,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  MalasIcons.warningFill,
                  size: _warningIconSize,
                  color: MalasColors.borderAttentionLip,
                ),
                const SizedBox(width: MalasSpace.s12),
                Expanded(
                  child: Text(warning.message, style: MalasText.bodyStrong),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SimpanBar extends StatelessWidget {
  const _SimpanBar();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final errorMessage = viewModel.errorMessage;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MalasColors.bgSurface,
        border: Border(
          top: BorderSide(
            color: MalasColors.borderCard,
            width: MalasSize.cardStroke,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MalasSpace.screen,
            MalasSpace.s12,
            MalasSpace.screen,
            MalasSpace.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: MalasSpace.s8),
                  child: Text(
                    errorMessage,
                    style: MalasText.bodySecondary.copyWith(
                      color: MalasColors.textError,
                    ),
                  ),
                ),
              LipButton(
                label: viewModel.isSaving
                    ? 'Menyimpan…'
                    : (errorMessage == null ? 'Simpan' : 'Coba lagi'),
                onPressed: viewModel.isSaving
                    ? null
                    : () => _simpan(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _simpan(BuildContext context, DraftViewModel viewModel) async {
    await viewModel.simpan();
    if (viewModel.isAllSaved && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// What the owner typed in the line editor. Applied only when they tap
/// Pakai, so closing the sheet changes nothing.
class LineEdit {
  const LineEdit({
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String? itemName;
  final String? quantity;
  final String? unit;
  final int? unitPrice;
  final int? lineTotal;

  void applyTo(DraftLine line) {
    line
      ..itemName = itemName
      ..quantity = quantity
      ..unit = unit
      ..unitPrice = unitPrice
      ..lineTotal = lineTotal;
  }
}

/// Spec §7.3: tapping a line shows the rest of it. An empty field saves as
/// empty, flagged by the server, never blocked (§5.4).
class LineEditorSheet extends StatefulWidget {
  const LineEditorSheet({super.key, required this.line});

  final DraftLine line;

  @override
  State<LineEditorSheet> createState() => _LineEditorSheetState();
}

class _LineEditorSheetState extends State<LineEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _lineTotalController;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    _nameController = TextEditingController(text: line.itemName ?? '');
    _quantityController = TextEditingController(text: line.quantity ?? '');
    _unitController = TextEditingController(text: line.unit ?? '');
    _unitPriceController = TextEditingController(
      text: _groupedOrEmpty(line.unitPrice),
    );
    _lineTotalController = TextEditingController(
      text: _groupedOrEmpty(line.lineTotal),
    );
  }

  /// A Retur line is negative, and the field shows only digits and dots,
  /// so the sign comes back from the line being edited.
  int? _withOriginalSign(int? typedTotal) {
    final isNegative = (widget.line.lineTotal ?? 0) < 0;
    return isNegative && typedTotal != null ? -typedTotal : typedTotal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _unitPriceController.dispose();
    _lineTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MalasSpace.screen,
        MalasSpace.s12,
        MalasSpace.screen,
        MalasSpace.s20 + keyboardInset + safeBottom,
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
          const SizedBox(height: MalasSpace.s16),
          Text('Ubah baris', style: MalasText.titleSection),
          const SizedBox(height: MalasSpace.s16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama'),
          ),
          const SizedBox(height: MalasSpace.s12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Jumlah'),
                ),
              ),
              const SizedBox(width: MalasSpace.s12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: MalasSpace.s12),
          TextField(
            controller: _unitPriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            style: MalasText.moneyRow,
            decoration: const InputDecoration(labelText: 'Harga satuan'),
          ),
          const SizedBox(height: MalasSpace.s12),
          TextField(
            controller: _lineTotalController,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            style: MalasText.moneyRow,
            decoration: const InputDecoration(labelText: 'Total'),
          ),
          const SizedBox(height: MalasSpace.s20),
          LipButton(
            label: 'Pakai',
            onPressed: () => Navigator.of(context).pop(
              LineEdit(
                itemName: _emptyToNull(_nameController.text),
                quantity: parseQuantityInput(_quantityController.text),
                unit: _emptyToNull(_unitController.text),
                unitPrice: parseRupiahInput(_unitPriceController.text),
                lineTotal: _withOriginalSign(
                  parseRupiahInput(_lineTotalController.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

MoneyText _draftMoney(Direction direction, int amount) {
  final effect = direction == Direction.masuk ? amount : -amount;
  return MoneyText(
    effect.abs(),
    sign: effect < 0 ? MoneySign.keluar : MoneySign.masuk,
  );
}

(CategoryTone, IconData) _toneForDraftLine(
  Direction direction,
  DraftLine line,
) {
  final name = (line.itemName ?? '').toLowerCase();
  bool has(List<String> words) => words.any(name.contains);
  if (has(['minum', 'teh', 'kopi', 'jus', 'es '])) {
    return (CategoryTone.minuman, MalasIcons.coffeeFill);
  }
  if (has(['gas', 'listrik', 'bensin', 'air'])) {
    return (CategoryTone.merah, MalasIcons.fireFill);
  }
  if (has(['bahan', 'beras', 'gula', 'minyak', 'telur', 'sayur'])) {
    return (CategoryTone.bahan, MalasIcons.basketFill);
  }
  if (has(['makan', 'nasi', 'goreng', 'mie', 'ayam'])) {
    return (CategoryTone.makanan, MalasIcons.bowlFoodFill);
  }
  if (direction == Direction.masuk) {
    return (CategoryTone.penjualan, MalasIcons.storefrontFill);
  }
  return (CategoryTone.lainnya, MalasIcons.receiptFill);
}

String? _emptyToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// "2 porsi", "0.5 kg", or null for a bare amount.
@visibleForTesting
String? describeQuantity(DraftLine line) {
  final quantity = line.quantity;
  if (quantity == null) return null;
  final unit = line.unit;
  return unit == null ? quantity : '$quantity $unit';
}

/// A typed rupiah amount, read as whole rupiah: "12.500", "12500" and
/// "Rp 12.500" are all 12500. Empty means no amount.
String _groupedOrEmpty(int? amount) =>
    amount == null ? '' : groupThousands(amount.abs());

int? parseRupiahInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}

/// A typed quantity as the decimal string the API carries. A comma is the
/// Indonesian decimal mark, so "0,5" is "0.5". Anything that isn't a number
/// is treated as empty, and the server flags the line.
String? parseQuantityInput(String text) {
  final normalised = text.trim().replaceAll(',', '.');
  if (normalised.isEmpty) return null;
  return double.tryParse(normalised) == null ? null : normalised;
}

/// A picked calendar date as `YYYY-MM-DD`.
String formatBusinessDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

const _formHeaderHeight = 216.0;
const _warningIconSize = 20.0;
const _handleWidth = 40.0;
const _handleHeight = 5.0;
