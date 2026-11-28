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
              height: _analisisHeaderHeight,
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
              controls: SegmentedSelector(
                isOnBrand: true,
                labels: [
                  for (final period in AnalyticsPeriod.values) period.label,
                ],
                selectedIndex: viewModel.range.period.index,
                onSelected: (index) =>
                    viewModel.selectPeriod(AnalyticsPeriod.values[index]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                sidePaddingFor(MediaQuery.sizeOf(context).width),
                MalasSpace.s8,
                sidePaddingFor(MediaQuery.sizeOf(context).width),
                MalasSpace.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeriodStepper(viewModel: viewModel),
                  const SizedBox(height: MalasSpace.s16),
                  if (viewModel.errorMessage case final message?)
                    _LoadFailed(message: message, onRetry: viewModel.load)
                  else if (summary == null)
                    const _AnalisisSkeleton()
                  else ...[
                    _SummarySection(summary: summary),
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
            MalasSpace.s24,
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
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ExportOptionRow(
                      icon: MalasIcons.chatCircleText,
                      label: 'Teks WhatsApp',
                      onTap: () =>
                          Navigator.of(sheetContext).pop(_ExportFormat.text),
                    ),
                    const Divider(indent: MalasSpace.s16),
                    _ExportOptionRow(
                      icon: MalasIcons.filePdf,
                      label: 'PDF',
                      onTap: () =>
                          Navigator.of(sheetContext).pop(_ExportFormat.pdf),
                    ),
                  ],
                ),
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

class _PeriodStepper extends StatelessWidget {
  const _PeriodStepper({required this.viewModel});

  final AnalisisViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: MalasSize.touch,
          height: MalasSize.touch,
          child: IconButton(
            tooltip: 'Sebelumnya',
            color: MalasColors.textPrimary,
            icon: const Icon(MalasIcons.caretLeft, size: _iconSize),
            onPressed: viewModel.showPrevious,
          ),
        ),
        Expanded(
          child: Text(
            formatPeriodLabel(viewModel.range),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MalasText.titleSection,
          ),
        ),
        SizedBox(
          width: MalasSize.touch,
          height: MalasSize.touch,
          child: IconButton(
            tooltip: 'Berikutnya',
            color: MalasColors.textPrimary,
            disabledColor: MalasColors.textDisabled,
            icon: const Icon(MalasIcons.caretRight, size: _iconSize),
            onPressed: viewModel.hasNext ? viewModel.showNext : null,
          ),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final balanceRows = <Widget>[
      for (final (label, amount) in [
        ('Modal', summary.notCountedInProfit.modal),
        ('Ambil pribadi', summary.notCountedInProfit.ambilPribadi),
        ('Pinjaman', summary.notCountedInProfit.pinjaman),
        ('Titipan', summary.notCountedInProfit.titipan),
      ])
        if (amount != 0)
          EntryRow(
            title: label,
            tone: CategoryTone.lainnya,
            icon: MalasIcons.receiptFill,
            money: MoneyText(
              amount.abs(),
              sign: amount < 0 ? MoneySign.keluar : MoneySign.neutral,
            ),
          ),
      EntryRow(
        title: 'Piutang',
        tone: CategoryTone.minuman,
        icon: MalasIcons.usersThreeFill,
        money: MoneyText(
          summary.piutangAtEnd.abs(),
          sign: summary.piutangAtEnd < 0 ? MoneySign.keluar : MoneySign.neutral,
        ),
      ),
      EntryRow(
        title: 'Utang',
        tone: CategoryTone.jeruk,
        icon: MalasIcons.handCoinsFill,
        money: MoneyText(
          summary.utangAtEnd.abs(),
          sign: summary.utangAtEnd < 0 ? MoneySign.keluar : MoneySign.neutral,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.untung case final untung?) ...[
          _UntungHeroCard(untung: untung, change: summary.changes.untung),
          const SizedBox(height: MalasSpace.s16),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FlowStatCard(
                  label: 'Masuk',
                  amount: summary.masuk,
                  isMasuk: true,
                  change: summary.changes.masuk,
                ),
              ),
              const SizedBox(width: MalasSpace.s12),
              Expanded(
                child: _FlowStatCard(
                  label: 'Keluar',
                  amount: summary.keluar,
                  isMasuk: false,
                  change: summary.changes.keluar,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MalasSpace.s24),
        RowsCard(rows: balanceRows),
        const SizedBox(height: MalasSpace.s24),
        _DaysRecordedBar(
          recorded: summary.daysRecorded,
          total: summary.daysInPeriod,
        ),
      ],
    );
  }
}

/// Flat bg/brand-soft hero card (no border) with Untung + MoneyText hero.
class _UntungHeroCard extends StatelessWidget {
  const _UntungHeroCard({required this.untung, required this.change});

  final int untung;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final changeValue = change;
    return Container(
      padding: const EdgeInsets.all(MalasSpace.s24),
      decoration: BoxDecoration(
        color: MalasColors.bgBrandSoft,
        borderRadius: BorderRadius.circular(MalasRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Untung', style: MalasText.bodySecondary)),
              if (changeValue != null)
                _ChangeTag(change: changeValue, isHigherBetter: true),
            ],
          ),
          const SizedBox(height: MalasSpace.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              untung.abs(),
              sign: untung < 0 ? MoneySign.keluar : MoneySign.masuk,
              size: MoneySize.hero,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStatCard extends StatelessWidget {
  const _FlowStatCard({
    required this.label,
    required this.amount,
    required this.isMasuk,
    required this.change,
  });

  final String label;
  final int amount;
  final bool isMasuk;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final changeValue = change;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MalasSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: MalasText.bodySecondary),
            const SizedBox(height: MalasSpace.s8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(
                amount.abs(),
                sign: isMasuk ? MoneySign.masuk : MoneySign.keluar,
              ),
            ),
            if (changeValue != null) ...[
              const SizedBox(height: MalasSpace.s8),
              _ChangeTag(change: changeValue, isHigherBetter: isMasuk),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeTag extends StatelessWidget {
  const _ChangeTag({required this.change, required this.isHigherBetter});

  final double change;
  final bool isHigherBetter;

  @override
  Widget build(BuildContext context) {
    final tone = change == 0
        ? TagTone.netral
        : (isHigherBetter ? change > 0 : change < 0)
        ? TagTone.lunas
        : TagTone.lewat;
    return TagChip(formatChange(change), tone: tone);
  }
}

class _DaysRecordedBar extends StatelessWidget {
  const _DaysRecordedBar({required this.recorded, required this.total});

  final int recorded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (recorded / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Hari dicatat', style: MalasText.bodySecondary),
            ),
            Text('$recorded dari $total', style: MalasText.bodyStrong),
          ],
        ),
        const SizedBox(height: MalasSpace.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(MalasRadius.xs),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: MalasSpace.s8,
            backgroundColor: MalasColors.bgSecondary,
            valueColor: const AlwaysStoppedAnimation(MalasColors.bgBrand),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: MalasSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Container(
            padding: const EdgeInsets.all(MalasSpace.s24),
            decoration: BoxDecoration(
              color: MalasColors.bgBrandSoft,
              borderRadius: BorderRadius.circular(MalasRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(width: _skeletonShortWidth, height: MalasSpace.s16),
                const SizedBox(height: MalasSpace.s8),
                _skeletonBox(width: _skeletonWideWidth, height: MalasSpace.s24),
              ],
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

const _analisisHeaderHeight = 192.0;
const _iconSize = 20.0;
const _handleWidth = 40.0;
const _handleHeight = 5.0;
const _skeletonShortWidth = 96.0;
const _skeletonWideWidth = 180.0;
