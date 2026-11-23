import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/home_repository.dart';
import '../../data/unsent_drafts_store.dart';
import '../../model/draft.dart';
import '../../model/home.dart';
import '../../model/transaction.dart';
import '../../viewmodel/beranda_view_model.dart';
import '../../viewmodel/session_view_model.dart';
import '../bicara/bicara_view.dart';
import '../catatan/piutang_utang_view.dart';
import '../draft/draft_view.dart';
import '../foto/foto_view.dart';
import '../format.dart';
import '../ketik/ketik_view.dart';
import '../settings/settings_view.dart';

/// Spec §6 Beranda, top to bottom: today's Masuk and Keluar with the
/// comparisons, the cards that have something, today's entries, and the
/// three record buttons at thumb height.
class BerandaView extends StatelessWidget {
  const BerandaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BerandaViewModel(
        homeRepository: HomeRepository(context.read<ApiClient>()),
        unsentDraftsStore: context.read<UnsentDraftsStore>(),
      )..load(),
      child: const _BerandaScreen(),
    );
  }
}

class _BerandaScreen extends StatelessWidget {
  const _BerandaScreen();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BerandaViewModel>();
    final home = viewModel.home;
    if (home != null) _reopenUnsentDrafts(context, viewModel, home);
    return Scaffold(
      appBar: AppBar(title: const _StoreNameTitle()),
      body: Column(
        children: [
          Expanded(
            child: home == null
                ? _FirstLoadState(viewModel: viewModel)
                : RefreshIndicator(
                    onRefresh: viewModel.load,
                    child: _HomeList(
                      home: home,
                      errorMessage: viewModel.errorMessage,
                    ),
                  ),
          ),
          _RecordButtons(
            // All three need the server's business date, so they wait for
            // /home.
            onBicara: home == null
                ? null
                : () => _readThenOpenDraft(
                    context,
                    captureRoute: BicaraView.route(),
                    businessToday: home.today.businessDate,
                    onChanged: viewModel.load,
                  ),
            onFoto: home == null
                ? null
                : () => _readThenOpenDraft(
                    context,
                    captureRoute: FotoView.route(),
                    businessToday: home.today.businessDate,
                    onChanged: viewModel.load,
                  ),
            onKetik: home == null
                ? null
                : () => openKetik(
                    context,
                    businessToday: home.today.businessDate,
                    onChanged: viewModel.load,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Spec §5.7, #25: drafts kept on the phone after a failed Simpan open again
/// on the next app open, with Coba lagi and the keys they were sent with.
void _reopenUnsentDrafts(
  BuildContext context,
  BerandaViewModel viewModel,
  Home home,
) {
  final unsentDrafts = viewModel.takeUnsentDrafts();
  if (unsentDrafts.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    openDraftScreen(
      context,
      drafts: [for (final unsent in unsentDrafts) unsent.draft],
      idempotencyKeys: [
        for (final unsent in unsentDrafts) unsent.idempotencyKey,
      ],
      isUnsent: true,
      businessToday: home.today.businessDate,
      onChanged: viewModel.load,
    );
  });
}

/// Bicara or Foto first, then the draft screen with what it read. Backing
/// out of the capture screen opens nothing.
Future<void> _readThenOpenDraft(
  BuildContext context, {
  required Route<AiReadResult> captureRoute,
  required String businessToday,
  required VoidCallback onChanged,
}) async {
  final readResult = await Navigator.of(context).push(captureRoute);
  if (readResult == null || !context.mounted) return;
  await openDraftScreen(
    context,
    drafts: readResult.drafts,
    warnings: readResult.warnings,
    businessToday: businessToday,
    onChanged: onChanged,
  );
}

class _FirstLoadState extends StatelessWidget {
  const _FirstLoadState({required this.viewModel});

  final BerandaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final errorMessage = viewModel.errorMessage;
    if (viewModel.isLoading || errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(errorMessage),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: viewModel.load,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _HomeList extends StatelessWidget {
  const _HomeList({required this.home, required this.errorMessage});

  final Home home;

  /// From a failed refresh, shown above the last loaded data.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final refreshError = errorMessage;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (refreshError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              refreshError,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        _TodayTotals(today: home.today, comparisons: home.comparisons),
        const SizedBox(height: 16),
        ..._buildCards(home.cards),
        if (home.entries.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Catatan hari ini',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final entry in home.entries) _EntryTile(entry: entry),
        ],
      ],
    );
  }
}

/// One card per thing that has something, in the order spec §6 lists them.
List<Widget> _buildCards(HomeCards cards) {
  final dueToday = cards.dueToday;
  final queuedReads = cards.queuedReads;
  return [
    for (final alert in cards.alerts)
      _HomeCard(icon: Icons.notifications_active_outlined, text: alert.message),
    if (cards.missedDays.isNotEmpty)
      _HomeCard(
        icon: Icons.event_busy_outlined,
        text:
            'Belum dicatat: ${cards.missedDays.map(formatWeekdayShort).join(', ')}',
      ),
    if (cards.hasOpenBalances)
      _HomeCard(
        icon: Icons.account_balance_wallet_outlined,
        text: _describeOpenBalances(cards),
        buildRoute: PiutangUtangView.route,
      ),
    if (dueToday != null)
      _HomeCard(
        icon: Icons.schedule_outlined,
        text: 'Jatuh tempo hari ini: $dueToday',
      ),
    if (queuedReads != null)
      _HomeCard(
        icon: Icons.hourglass_top_outlined,
        text: '$queuedReads menunggu dibaca',
      ),
  ];
}

String _describeOpenBalances(HomeCards cards) {
  final piutang = cards.piutang;
  final utang = cards.utang;
  return [
    if (piutang != null) 'Piutang ${formatRupiah(piutang)}',
    if (utang != null) 'Utang ${formatRupiah(utang)}',
  ].join(' · ');
}

class _TodayTotals extends StatelessWidget {
  const _TodayTotals({required this.today, required this.comparisons});

  final DayTotals today;
  final List<Comparison> comparisons;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final comparisonText = comparisons
        .map(
          (comparison) =>
              '${comparison.label} ${formatRupiah(comparison.masuk)}',
        )
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Total(label: 'Masuk', amount: today.masuk),
            ),
            Expanded(
              child: _Total(label: 'Keluar', amount: today.keluar),
            ),
          ],
        ),
        if (comparisonText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comparisonText, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelLarge),
        Text(formatRupiah(amount), style: textTheme.headlineSmall),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.icon, required this.text, this.buildRoute});

  final IconData icon;
  final String text;

  /// The screen a tap opens, for cards that lead somewhere.
  final Route<void> Function()? buildRoute;

  @override
  Widget build(BuildContext context) {
    final buildRoute = this.buildRoute;
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        onTap: buildRoute == null
            ? null
            : () => Navigator.of(context).push(buildRoute()),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final Transaction entry;

  @override
  Widget build(BuildContext context) {
    final isMasuk = entry.direction == Direction.masuk;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isMasuk ? Icons.south_west : Icons.north_east),
      title: Text(describeEntry(entry)),
      subtitle: entry.isFullyPaid
          ? null
          : Text('Sisa ${formatRupiah(entry.remaining)}'),
      trailing: Text(formatEntryTotal(entry)),
    );
  }
}

/// Ketik opens its quick amount. Bicara and Foto read first, then open the
/// draft screen with what was read (§8.2).
class _RecordButtons extends StatelessWidget {
  const _RecordButtons({
    required this.onBicara,
    required this.onFoto,
    required this.onKetik,
  });

  final VoidCallback? onBicara;
  final VoidCallback? onFoto;

  final VoidCallback? onKetik;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            for (final (label, icon, onPressed) in [
              ('Bicara', Icons.mic, onBicara),
              ('Foto', Icons.photo_camera, onFoto),
              ('Ketik', Icons.keyboard, onKetik),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: onPressed,
                    icon: Icon(icon),
                    label: Text(label),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The business name opens Settings (§6). Without a session, as in a test
/// that shows Beranda alone, it reads "Beranda".
class _StoreNameTitle extends StatelessWidget {
  const _StoreNameTitle();

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionViewModel?>()?.account;
    if (account == null) return const Text('Beranda');
    return InkWell(
      onTap: () => Navigator.of(context).push(SettingsView.route(account)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(account.store.name, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
    );
  }
}
