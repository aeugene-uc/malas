import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/home_repository.dart';
import '../../model/home.dart';
import '../../model/transaction.dart';
import '../../viewmodel/beranda_view_model.dart';
import '../bicara/bicara_view.dart';
import '../foto/foto_view.dart';
import '../format.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
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
          const _RecordButtons(),
        ],
      ),
    );
  }
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
  const _HomeCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: Icon(icon), title: Text(text)),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final Transaction entry;

  @override
  Widget build(BuildContext context) {
    final isMasuk = entry.direction == Direction.masuk;
    final sign = isMasuk ? '+' : '-';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isMasuk ? Icons.south_west : Icons.north_east),
      title: Text(describeEntry(entry)),
      subtitle: entry.isFullyPaid
          ? null
          : Text('Sisa ${formatRupiah(entry.remaining)}'),
      trailing: Text('$sign${formatRupiah(entry.total)}'),
    );
  }
}

/// What the owner sees for an entry (spec §5.3: name, quantity, total):
/// "Pak Budi · Nasi goreng 2 porsi, Es teh 4 gelas".
@visibleForTesting
String describeEntry(Transaction entry) {
  final lineDescriptions = entry.lines.map(_describeLine).join(', ');
  final person = entry.person;
  if (person == null) return lineDescriptions;
  return lineDescriptions.isEmpty
      ? person.name
      : '${person.name} · $lineDescriptions';
}

String _describeLine(TransactionLine line) {
  // A bare amount has no item, so its category is the only name it has.
  final name = line.item?.name ?? line.category?.name ?? '';
  final quantity = line.quantity;
  if (quantity == null) return name;
  final unit = line.unit;
  return unit == null ? '$name $quantity' : '$name $quantity $unit';
}

/// Ketik opens its screen once F3 lands. The drafts Bicara and Foto return
/// open the draft screen once F3 lands too.
class _RecordButtons extends StatelessWidget {
  const _RecordButtons();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            for (final (label, icon, buildRoute) in [
              ('Bicara', Icons.mic, BicaraView.route),
              ('Foto', Icons.photo_camera, FotoView.route),
              ('Ketik', Icons.keyboard, null),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: buildRoute == null
                        ? null
                        : () => Navigator.of(context).push(buildRoute()),
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
