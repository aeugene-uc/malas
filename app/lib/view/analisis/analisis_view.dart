import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/analytics_repository.dart';
import '../../data/api_client.dart';
import '../../model/analytics.dart';
import '../../model/transaction_filter.dart';
import '../../viewmodel/analisis_view_model.dart';
import '../../viewmodel/session_view_model.dart';
import '../catatan/catatan_view.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';
import 'analisis_pdf.dart';
import 'analisis_text.dart';

/// Spec §7.6: period, summary, two ranked lists, alerts and Ekspor.
class AnalisisView extends StatelessWidget {
  const AnalisisView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AnalisisViewModel(
        analyticsRepository: AnalyticsRepository(context.read<ApiClient>()),
        today: DateTime.now,
      )..load(),
      child: const _AnalisisScreen(),
    );
  }
}

class _AnalisisScreen extends StatelessWidget {
  const _AnalisisScreen();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AnalisisViewModel>();
    final summary = viewModel.summary;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            BrandHeader(
              title: 'Analisis',
              actions: [
                IconButton(
                  tooltip: 'Ekspor',
                  color: MalasColors.textOnBrand,
                  disabledColor: MalasColors.decoTerang,
                  icon: const Icon(MalasIcons.shareNetwork),
                  onPressed: summary == null
                      ? null
                      : () => _showExportChoices(context),
                ),
              ],
              controls: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final (index, period)
                          in AnalyticsPeriod.values.indexed) ...[
                        if (index > 0) const SizedBox(width: MalasSpace.s8),
                        Expanded(
                          child: _PeriodChip(
                            label: period.label,
                            isSelected: viewModel.range.period == period,
                            onPressed: () => viewModel.selectPeriod(period),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MalasSpace.s12),
                  _PeriodStepper(viewModel: viewModel),
                ],
              ),
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
                  if (viewModel.errorMessage case final message?)
                    _LoadFailed(message: message, onRetry: viewModel.load)
                  else if (summary == null)
                    const _AnalisisSkeleton()
                  else ...[
                    _SummaryCard(summary: summary),
                    if (viewModel.masukRows.isNotEmpty) ...[
                      const SizedBox(height: MalasSpace.s24),
                      _RankedList(
                        title: 'Masuk per barang',
                        rows: viewModel.masukRows,
                        isMasuk: true,
                      ),
                    ],
                    if (viewModel.keluarRows.isNotEmpty) ...[
                      const SizedBox(height: MalasSpace.s24),
                      _RankedList(
                        title: 'Keluar per kategori',
                        rows: viewModel.keluarRows,
                        isMasuk: false,
                      ),
                    ],
                    if (viewModel.alerts.isNotEmpty) ...[
                      const SizedBox(height: MalasSpace.s24),
                      const SectionHeader(title: 'Peringatan'),
                      for (final (index, alert) in viewModel.alerts.indexed) ...[
                        if (index > 0) const SizedBox(height: MalasSpace.s12),
                        _AlertCard(message: alert.message),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ekspor (§7.6): a WhatsApp text summary or a PDF, both through the
  /// phone's share sheet.
  Future<void> _showExportChoices(BuildContext context) async {
    final chosenFormat = await showModalBottomSheet<_ExportFormat>(
      context: context,
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => SafeArea(
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
              Text('Ekspor', style: MalasText.titleSection),
              const SizedBox(height: MalasSpace.s12),
              RowsCard(
                rows: [
                  _ExportOptionRow(
                    icon: MalasIcons.chatCircleText,
                    label: 'Teks WhatsApp',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_ExportFormat.text),
                  ),
                  _ExportOptionRow(
                    icon: MalasIcons.filePdf,
                    label: 'PDF',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_ExportFormat.pdf),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosenFormat == null || !context.mounted) return;
    final viewModel = context.read<AnalisisViewModel>();
    final storeName =
        context.read<SessionViewModel?>()?.account?.store.name ?? 'MALAS';
    final summary = viewModel.summary!;
    switch (chosenFormat) {
      case _ExportFormat.text:
        final text = buildWhatsAppSummary(
          storeName: storeName,
          range: viewModel.range,
          summary: summary,
          masukRows: viewModel.masukRows,
        );
        await SharePlus.instance.share(ShareParams(text: text));
      case _ExportFormat.pdf:
        final pdfBytes = await buildAnalisisPdf(
          storeName: storeName,
          range: viewModel.range,
          summary: summary,
          masukRows: viewModel.masukRows,
          keluarRows: viewModel.keluarRows,
        );
        final fileName = '$storeName ${formatPeriodLabel(viewModel.range)}.pdf';
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(pdfBytes, mimeType: 'application/pdf')],
            fileNameOverrides: [fileName],
          ),
        );
    }
  }
}

enum _ExportFormat { text, pdf }

class _ExportOptionRow extends StatelessWidget {
  const _ExportOptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MalasSize.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MalasSpace.s16,
            vertical: MalasSpace.s12,
          ),
          child: Row(
            children: [
              Icon(icon, size: _iconSize, color: MalasColors.iconBrand),
              const SizedBox(width: MalasSpace.s12),
              Expanded(child: Text(label, style: MalasText.titleItem)),
              const Icon(
                MalasIcons.caretRight,
                size: _iconSize,
                color: MalasColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DESIGN.md §2 on-brand filter chip for Minggu / Bulan / Tahun.
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
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

class _PeriodStepper extends StatelessWidget {
  const _PeriodStepper({required this.viewModel});

  final AnalisisViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MalasSize.touch,
      decoration: BoxDecoration(
        color: MalasColors.bgBrandPressed,
        borderRadius: BorderRadius.circular(MalasRadius.md),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Sebelumnya',
            color: MalasColors.textOnBrand,
            icon: const Icon(MalasIcons.caretLeft, size: _iconSize),
            onPressed: viewModel.showPrevious,
          ),
          Expanded(
            child: Text(
              formatPeriodLabel(viewModel.range),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MalasText.bodyStrong.copyWith(
                color: MalasColors.textOnBrand,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Berikutnya',
            color: MalasColors.textOnBrand,
            disabledColor: MalasColors.decoTerang,
            icon: const Icon(MalasIcons.caretRight, size: _iconSize),
            onPressed: viewModel.hasNext ? viewModel.showNext : null,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final notCounted = [
      ('Modal', summary.notCountedInProfit.modal),
      ('Ambil pribadi', summary.notCountedInProfit.ambilPribadi),
      ('Pinjaman', summary.notCountedInProfit.pinjaman),
      ('Titipan', summary.notCountedInProfit.titipan),
    ].where((entry) => entry.$2 != 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MalasSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.untung case final untung?) ...[
              _SummaryFigure(
                label: 'Untung',
                amount: untung,
                sign: untung < 0 ? MoneySign.keluar : MoneySign.masuk,
                change: summary.changes.untung,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: MalasSpace.s12),
                child: Divider(),
              ),
            ],
            _SummaryFigure(
              label: 'Masuk',
              amount: summary.masuk,
              sign: MoneySign.masuk,
              change: summary.changes.masuk,
            ),
            const SizedBox(height: MalasSpace.s12),
            _SummaryFigure(
              label: 'Keluar',
              amount: summary.keluar,
              sign: MoneySign.keluar,
              change: summary.changes.keluar,
            ),
            if (notCounted.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: MalasSpace.s12),
                child: Divider(),
              ),
              for (final (index, entry) in notCounted.indexed) ...[
                if (index > 0) const SizedBox(height: MalasSpace.s8),
                _BalanceLine(label: entry.$1, amount: entry.$2),
              ],
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: MalasSpace.s12),
              child: Divider(),
            ),
            Text(
              '${summary.daysRecorded} dari ${summary.daysInPeriod} '
              'hari dicatat',
              style: MalasText.bodySecondary,
            ),
            const SizedBox(height: MalasSpace.s8),
            _BalanceLine(label: 'Piutang', amount: summary.piutangAtEnd),
            const SizedBox(height: MalasSpace.s4),
            _BalanceLine(label: 'Utang', amount: summary.utangAtEnd),
          ],
        ),
      ),
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({
    required this.label,
    required this.amount,
    required this.sign,
    required this.change,
  });

  final String label;
  final int amount;
  final MoneySign sign;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final changeValue = change;
    final tagTone = switch (changeValue) {
      final value? when value > 0 => TagTone.lunas,
      final value? when value < 0 => TagTone.lewat,
      _ => TagTone.netral,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: MalasText.bodySecondary)),
            TagChip(formatChange(changeValue), tone: tagTone),
          ],
        ),
        const SizedBox(height: MalasSpace.s4),
        MoneyText(amount.abs(), sign: sign, size: MoneySize.large),
      ],
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: MalasText.bodySecondary)),
        MoneyText(
          amount.abs(),
          sign: amount < 0 ? MoneySign.keluar : MoneySign.neutral,
        ),
      ],
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({
    required this.title,
    required this.rows,
    required this.isMasuk,
  });

  final String title;
  final List<RankedRow> rows;
  final bool isMasuk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        RowsCard(
          rows: [
            for (final row in rows) _RankedRowTile(row: row, isMasuk: isMasuk),
          ],
        ),
      ],
    );
  }
}

class _RankedRowTile extends StatelessWidget {
  const _RankedRowTile({required this.row, required this.isMasuk});

  final RankedRow row;
  final bool isMasuk;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = _toneForRankedRow(row, isMasuk: isMasuk);
    final rowId = row.id;
    return InkWell(
      onTap: rowId == null
          ? null
          : () => Navigator.of(context).push(
              CatatanView.route(
                FilterFocus(
                  kind: row.isItem ? FocusKind.item : FocusKind.category,
                  id: rowId,
                  name: row.name,
                ),
              ),
            ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MalasSize.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MalasSpace.s16,
            vertical: MalasSpace.s12,
          ),
          child: Row(
            children: [
              CategoryTile(tone: tone, icon: icon),
              const SizedBox(width: MalasSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MalasText.titleItem,
                    ),
                    const SizedBox(height: MalasSpace.s8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MalasRadius.xs),
                      child: LinearProgressIndicator(
                        value: row.share.clamp(0.0, 1.0),
                        minHeight: MalasSpace.s8,
                        backgroundColor: MalasColors.bgSecondary,
                        valueColor: AlwaysStoppedAnimation(
                          isMasuk ? MalasColors.masuk : tone.base,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MalasSpace.s12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    row.amount.abs(),
                    sign: isMasuk ? MoneySign.masuk : MoneySign.keluar,
                  ),
                  Text(formatShare(row.share), style: MalasText.bodySecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            size: _iconSize,
            color: MalasColors.borderAttentionLip,
          ),
          const SizedBox(width: MalasSpace.s12),
          Expanded(child: Text(message, style: MalasText.bodyStrong)),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MalasSpace.s32),
      child: Column(
        children: [
          Text(message, style: MalasText.body, textAlign: TextAlign.center),
          const SizedBox(height: MalasSpace.s16),
          LipButton(label: 'Coba lagi', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// DESIGN.md §4.3: skeleton blocks at the real card/row sizes.
class _AnalisisSkeleton extends StatelessWidget {
  const _AnalisisSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MalasSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(width: _skeletonShortWidth, height: MalasSpace.s16),
                  const SizedBox(height: MalasSpace.s8),
                  _skeletonBox(width: _skeletonWideWidth, height: MalasSpace.s32),
                  const SizedBox(height: MalasSpace.s16),
                  _skeletonBox(width: _skeletonShortWidth, height: MalasSpace.s16),
                  const SizedBox(height: MalasSpace.s8),
                  _skeletonBox(width: _skeletonWideWidth, height: MalasSpace.s32),
                ],
              ),
            ),
          ),
          const SizedBox(height: MalasSpace.s24),
          RowsCard(
            rows: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.all(MalasSpace.s16),
                  child: Row(
                    children: [
                      _skeletonBox(
                        width: MalasSize.categoryTile,
                        height: MalasSize.categoryTile,
                        radius: MalasRadius.sm,
                      ),
                      const SizedBox(width: MalasSpace.s12),
                      Expanded(
                        child: _skeletonBox(
                          width: double.infinity,
                          height: MalasSpace.s16,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    double radius = MalasRadius.xs,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: MalasColors.bgSkeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

(CategoryTone, IconData) _toneForRankedRow(
  RankedRow row, {
  required bool isMasuk,
}) {
  final name = row.name.toLowerCase();
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
  if (isMasuk) return (CategoryTone.penjualan, MalasIcons.storefrontFill);
  return (CategoryTone.lainnya, MalasIcons.receiptFill);
}

const _iconSize = 20.0;
const _handleWidth = 40.0;
const _handleHeight = 5.0;
const _skeletonShortWidth = 96.0;
const _skeletonWideWidth = 180.0;
