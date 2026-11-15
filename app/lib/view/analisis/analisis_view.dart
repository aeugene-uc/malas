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
import '../format.dart';
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
      appBar: AppBar(
        title: const Text('Analisis'),
        actions: [
          IconButton(
            tooltip: 'Ekspor',
            icon: const Icon(Icons.ios_share),
            onPressed: summary == null
                ? null
                : () => _showExportChoices(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<AnalyticsPeriod>(
                segments: [
                  for (final period in AnalyticsPeriod.values)
                    ButtonSegment(value: period, label: Text(period.label)),
                ],
                selected: {viewModel.range.period},
                onSelectionChanged: (periods) =>
                    viewModel.selectPeriod(periods.single),
              ),
            ),
            _PeriodStepper(viewModel: viewModel),
            if (viewModel.errorMessage case final message?)
              _LoadFailed(message: message, onRetry: viewModel.load)
            else if (summary == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _SummaryCard(summary: summary),
              _RankedList(title: 'Masuk per barang', rows: viewModel.masukRows),
              _RankedList(
                title: 'Keluar per kategori',
                rows: viewModel.keluarRows,
              ),
              if (viewModel.alerts.isNotEmpty) ...[
                const _SectionTitle('Peringatan'),
                for (final alert in viewModel.alerts)
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(alert.message),
                  ),
              ],
            ],
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
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Teks WhatsApp'),
              onTap: () => Navigator.of(sheetContext).pop(_ExportFormat.text),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.of(sheetContext).pop(_ExportFormat.pdf),
            ),
          ],
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

class _PeriodStepper extends StatelessWidget {
  const _PeriodStepper({required this.viewModel});

  final AnalisisViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Sebelumnya',
          icon: const Icon(Icons.chevron_left),
          onPressed: viewModel.showPrevious,
        ),
        Expanded(
          child: Text(
            formatPeriodLabel(viewModel.range),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Berikutnya',
          icon: const Icon(Icons.chevron_right),
          onPressed: viewModel.hasNext ? viewModel.showNext : null,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FigureRow(
              label: 'Masuk',
              amount: summary.masuk,
              change: summary.changes.masuk,
            ),
            _FigureRow(
              label: 'Keluar',
              amount: summary.keluar,
              change: summary.changes.keluar,
            ),
            if (summary.untung case final untung?)
              _FigureRow(
                label: 'Untung',
                amount: untung,
                change: summary.changes.untung,
                isEmphasised: true,
              ),
            for (final line in notCountedLines(summary.notCountedInProfit))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(line, style: textTheme.bodySmall),
              ),
            const Divider(height: 24),
            Text(
              '${summary.daysRecorded} dari ${summary.daysInPeriod} '
              'hari dicatat',
            ),
            const SizedBox(height: 4),
            Text(
              'Piutang ${formatRupiah(summary.piutangAtEnd)} · '
              'Utang ${formatRupiah(summary.utangAtEnd)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({
    required this.label,
    required this.amount,
    required this.change,
    this.isEmphasised = false,
  });

  final String label;
  final int amount;
  final double? change;
  final bool isEmphasised;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amountStyle = isEmphasised
        ? textTheme.titleLarge
        : textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(formatRupiah(amount), style: amountStyle),
          SizedBox(
            width: 56,
            child: Text(
              formatChange(change),
              textAlign: TextAlign.end,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.title, required this.rows});

  final String title;
  final List<RankedRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title),
        for (final row in rows)
          ListTile(
            onTap: () => Navigator.of(context).push(
              CatatanView.route(
                FilterFocus(
                  kind: row.isItem ? FocusKind.item : FocusKind.category,
                  id: row.id,
                  name: row.name,
                ),
              ),
            ),
            title: Text(row.name),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: row.share),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatRupiah(row.amount)),
                Text(
                  formatShare(row.share),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
