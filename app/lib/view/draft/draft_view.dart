import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/draft_repository.dart';
import '../../model/draft.dart';
import '../../model/transaction.dart';
import '../../viewmodel/draft_view_model.dart';
import '../format.dart';

/// Opens the draft screen for what a read (Bicara, Foto) or Ketik produced.
/// After Simpan it shows the 10-second Batal toast (spec §5.2) on the
/// caller's screen. [onChanged] runs after a save and after a Batal, so the
/// caller can reload what it shows.
Future<void> openDraftScreen(
  BuildContext context, {
  required List<Draft> drafts,
  List<ReadWarning> warnings = const [],
  required String businessToday,
  required VoidCallback onChanged,
}) async {
  final viewModel = DraftViewModel(
    draftRepository: context.read<DraftRepository>(),
    businessToday: businessToday,
    drafts: drafts,
    warnings: warnings,
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

/// Spec §7.3: every draft from one input, each line as name, quantity and
/// total. Tapping a line opens the rest. Nothing is saved before Simpan.
class DraftView extends StatelessWidget {
  const DraftView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Draf')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DateChips(),
          const SizedBox(height: 12),
          for (
            var draftIndex = 0;
            draftIndex < viewModel.drafts.length;
            draftIndex++
          )
            _DraftCard(draftIndex: draftIndex),
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
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Hari ini'),
          selected: viewModel.dateChoice == DateChoice.hariIni,
          onSelected: (_) => viewModel.selectDate(DateChoice.hariIni),
        ),
        ChoiceChip(
          label: const Text('Kemarin'),
          selected: viewModel.dateChoice == DateChoice.kemarin,
          onSelected: (_) => viewModel.selectDate(DateChoice.kemarin),
        ),
        ChoiceChip(
          label: Text(pickedDate ?? 'Pilih tanggal'),
          selected: viewModel.dateChoice == DateChoice.pilihTanggal,
          onSelected: (_) => _pickDate(context, viewModel),
        ),
      ],
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

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draftIndex});

  final int draftIndex;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final draft = viewModel.drafts[draftIndex];
    final textTheme = Theme.of(context).textTheme;
    final isMasuk = draft.direction == Direction.masuk;
    final personName = draft.personName;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                [isMasuk ? 'Masuk' : 'Keluar', ?personName].join(' · '),
                style: textTheme.titleMedium,
              ),
              subtitle: draft.payments.isEmpty
                  ? const Text('Belum dibayar')
                  : null,
              trailing: Text(
                formatRupiah(draft.total),
                style: textTheme.titleMedium,
              ),
            ),
            _WarningChips(
              warnings: viewModel.warningsFor(draftIndex: draftIndex),
            ),
            for (var lineIndex = 0; lineIndex < draft.lines.length; lineIndex++)
              _LineTile(draftIndex: draftIndex, lineIndex: lineIndex),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.draftIndex, required this.lineIndex});

  final int draftIndex;
  final int lineIndex;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final line = viewModel.drafts[draftIndex].lines[lineIndex];
    final lineTotal = line.lineTotal;
    final quantityText = describeQuantity(line);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          // A bare amount ("bon Pak Budi 30 ribu") has no item.
          title: Text(line.itemName ?? 'Tanpa barang'),
          subtitle: quantityText == null ? null : Text(quantityText),
          trailing: Text(lineTotal == null ? '—' : formatRupiah(lineTotal)),
          onTap: () => _openLineEditor(context, viewModel),
        ),
        _WarningChips(
          warnings: viewModel.warningsFor(
            draftIndex: draftIndex,
            lineIndex: lineIndex,
          ),
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

class _WarningChips extends StatelessWidget {
  const _WarningChips({required this.warnings});

  final List<ReadWarning> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final warning in warnings)
            Chip(
              avatar: Icon(
                Icons.error_outline,
                size: 18,
                color: colorScheme.onTertiaryContainer,
              ),
              label: Text(warning.message),
              backgroundColor: colorScheme.tertiaryContainer,
              labelStyle: TextStyle(color: colorScheme.onTertiaryContainer),
            ),
        ],
      ),
    );
  }
}

class _SimpanBar extends StatelessWidget {
  const _SimpanBar();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DraftViewModel>();
    final errorMessage = viewModel.errorMessage;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: viewModel.isSaving
                  ? null
                  : () => _simpan(context, viewModel),
              child: viewModel.isSaving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(errorMessage == null ? 'Simpan' : 'Coba lagi'),
            ),
          ],
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
      text: line.unitPrice?.toString() ?? '',
    );
    _lineTotalController = TextEditingController(
      text: line.lineTotal?.toString() ?? '',
    );
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama'),
          ),
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
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                ),
              ),
            ],
          ),
          TextField(
            controller: _unitPriceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Harga satuan'),
          ),
          TextField(
            controller: _lineTotalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Navigator.of(context).pop(
              LineEdit(
                itemName: _emptyToNull(_nameController.text),
                quantity: parseQuantityInput(_quantityController.text),
                unit: _emptyToNull(_unitController.text),
                unitPrice: parseRupiahInput(_unitPriceController.text),
                lineTotal: parseRupiahInput(_lineTotalController.text),
              ),
            ),
            child: const Text('Pakai'),
          ),
        ],
      ),
    );
  }
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
