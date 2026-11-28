import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/home_repository.dart';
import '../../data/unsent_drafts_store.dart';
import '../../model/draft.dart';
import '../../model/home.dart';
import '../../model/transaction.dart';
import '../../viewmodel/app_shell_view_model.dart';
import '../../viewmodel/beranda_view_model.dart';
import '../../viewmodel/session_view_model.dart';
import '../bicara/bicara_view.dart';
import '../catatan/piutang_utang_view.dart';
import '../draft/draft_view.dart';
import '../foto/foto_view.dart';
import '../format.dart';
import '../ketik/ketik_view.dart';
import '../settings/settings_view.dart';
import '../theme/brand_header.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';
import '../theme/icons.dart';

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

class _BerandaScreen extends StatefulWidget {
  const _BerandaScreen();

  @override
  State<_BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<_BerandaScreen> {
  late final AppShellViewModel _appShell;

  /// The tab stays alive in the shell's IndexedStack, so a Retur, Bayar or
  /// Hapus made in Catatan only shows once Beranda loads again on opening.
  @override
  void initState() {
    super.initState();
    _appShell = context.read<AppShellViewModel>()
      ..addListener(_reloadWhenOpened);
  }

  @override
  void dispose() {
    _appShell.removeListener(_reloadWhenOpened);
    super.dispose();
  }

  void _reloadWhenOpened() {
    if (_appShell.selectedTab == AppTab.beranda) {
      context.read<BerandaViewModel>().load();
      _runPendingCapture();
    }
  }

  /// Any save ends the guided entry, whichever button made it.
  void _onChanged() {
    context.read<BerandaViewModel>().load();
    context.read<SessionViewModel?>()?.finishGuidedEntry();
  }

  /// The nav mic's choice (§4.1). Every mode needs the server's business
  /// date, so it waits for /home.
  void _runPendingCapture() {
    final home = context.read<BerandaViewModel>().home;
    if (home == null) return;
    final mode = _appShell.takePendingCapture();
    if (mode == null) return;
    final businessToday = home.today.businessDate;
    switch (mode) {
      case CaptureMode.bicara:
        _readThenOpenDraft(
          context,
          captureRoute: BicaraView.route(),
          businessToday: businessToday,
          onChanged: _onChanged,
        );
      case CaptureMode.foto:
        _readThenOpenDraft(
          context,
          captureRoute: FotoView.route(),
          businessToday: businessToday,
          onChanged: _onChanged,
        );
      case CaptureMode.ketik:
        openKetik(context, businessToday: businessToday, onChanged: _onChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BerandaViewModel>();
    final session = context.watch<SessionViewModel?>();
    final isGuidedEntryDue = session?.isGuidedEntryDue ?? false;
    final home = viewModel.home;
    if (home != null) {
      _reopenUnsentDrafts(context, viewModel, home);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runPendingCapture();
      });
    }
    return Scaffold(
      body: home == null
          ? _FirstLoadState(viewModel: viewModel)
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: _HomeList(
                home: home,
                errorMessage: viewModel.errorMessage,
                guidedEntry: isGuidedEntryDue
                    ? _GuidedEntryCard(onLewati: session!.finishGuidedEntry)
                    : null,
              ),
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
  const _HomeList({
    required this.home,
    required this.errorMessage,
    required this.guidedEntry,
  });

  final Home home;

  /// From a failed refresh, shown above the last loaded data.
  final String? errorMessage;

  /// Shown first, above the shortcuts, while the guided entry is due.
  final Widget? guidedEntry;

  @override
  Widget build(BuildContext context) {
    final refreshError = errorMessage;
    final cards = home.cards;
    final masukToday = home.entries
        .where((entry) => entry.direction == Direction.masuk)
        .fold(0, (sum, entry) => sum + entry.total);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TodayHeader(today: home.today, comparisons: home.comparisons),
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
              if (refreshError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: MalasSpace.s12),
                  child: Text(
                    refreshError,
                    style: MalasText.bodySecondary.copyWith(
                      color: MalasColors.textError,
                    ),
                  ),
                ),
              ?guidedEntry,
              if (cards.hasOpenBalances || cards.dueToday != null) ...[
                _Shortcuts(cards: cards),
                const SizedBox(height: MalasSpace.s24),
              ],
              for (final attention in _attentionLines(cards)) ...[
                _AttentionCard(text: attention),
                const SizedBox(height: MalasSpace.s12),
              ],
              if (home.entries.isNotEmpty) ...[
                const SizedBox(height: MalasSpace.s12),
                SectionHeader(
                  title: 'Hari ini',
                  trailing: masukToday == 0
                      ? null
                      : MoneyText(masukToday, sign: MoneySign.masuk),
                ),
                RowsCard(
                  rows: [
                    for (final entry in home.entries) EntryRowFor(entry: entry),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Cards that need a look, in the order spec §6 lists them.
List<String> _attentionLines(HomeCards cards) {
  final queuedReads = cards.queuedReads;
  return [
    for (final alert in cards.alerts) alert.message,
    if (cards.missedDays.isNotEmpty)
      'Belum dicatat: ${cards.missedDays.map(formatWeekdayShort).join(', ')}',
    if (queuedReads != null) '$queuedReads menunggu dibaca',
  ];
}

/// A1 Kepala: the store, today's Masuk large, comparisons as chips and
/// Keluar on a darker bar.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.today, required this.comparisons});

  final DayTotals today;
  final List<Comparison> comparisons;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<SessionViewModel?>()?.account;
    final onBrandSecondary = MalasText.bodySecondary.copyWith(
      color: MalasColors.textOnBrandSecondary,
    );
    return BrandHeader(
      // Without a session, as in a test that shows Beranda alone, it reads
      // "Beranda".
      title: account?.store.name ?? 'Beranda',
      subtitle: formatEntryDate(today.businessDate),
      height: 330,
      actions: [
        if (account != null)
          IconButton(
            tooltip: 'Pengaturan',
            color: MalasColors.textOnBrand,
            onPressed: () =>
                Navigator.of(context).push(SettingsView.route(account)),
            icon: const Icon(MalasIcons.gear),
          ),
      ],
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Masuk hari ini', style: onBrandSecondary),
          MoneyText(
            today.masuk,
            size: MoneySize.hero,
            color: MalasColors.textOnBrand,
          ),
          if (comparisons.isNotEmpty)
            Wrap(
              spacing: MalasSpace.s8,
              runSpacing: MalasSpace.s4,
              children: [
                for (final comparison in comparisons)
                  _OnBrandChip(
                    '${comparison.label} ${formatRupiah(comparison.masuk)}',
                  ),
              ],
            ),
          const SizedBox(height: MalasSpace.s8),
          Container(
            height: MalasSize.touch,
            padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
            decoration: BoxDecoration(
              color: MalasColors.bgBrandPressed,
              borderRadius: BorderRadius.circular(MalasRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Keluar hari ini', style: onBrandSecondary),
                ),
                MoneyText(
                  today.keluar,
                  sign: MoneySign.keluar,
                  color: MalasColors.textOnBrand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnBrandChip extends StatelessWidget {
  const _OnBrandChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MalasSpace.s8,
        vertical: MalasSpace.s4,
      ),
      decoration: BoxDecoration(
        color: MalasColors.bgBrandPressed,
        borderRadius: BorderRadius.circular(MalasRadius.xs),
      ),
      child: Text(
        label,
        style: MalasText.labelTag.copyWith(color: MalasColors.textOnBrand),
      ),
    );
  }
}

/// §3 shortcut row: Piutang, Utang and Jatuh tempo tiles in equal columns.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.cards});

  final HomeCards cards;

  @override
  Widget build(BuildContext context) {
    final piutang = cards.piutang;
    final utang = cards.utang;
    final dueToday = cards.dueToday;
    void openBalances() => Navigator.of(context).push(PiutangUtangView.route());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (piutang != null)
          _ShortcutTile(
            label: 'Piutang',
            value: formatRupiah(piutang),
            icon: MalasIcons.usersThreeFill,
            tone: CategoryTone.minuman,
            onTap: openBalances,
          ),
        if (utang != null)
          _ShortcutTile(
            label: 'Utang',
            value: formatRupiah(utang),
            icon: MalasIcons.handCoinsFill,
            tone: CategoryTone.jeruk,
            onTap: openBalances,
          ),
        if (dueToday != null)
          _ShortcutTile(
            label: 'Jatuh tempo',
            value: '$dueToday hari ini',
            icon: MalasIcons.calendarBlankFill,
            tone: CategoryTone.merah,
            onTap: openBalances,
          ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final CategoryTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label $value',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              SizedBox(
                width: 60,
                child: LipPressable(
                  onPressed: onTap,
                  fill: tone.base,
                  lip: tone.lip,
                  borderRadius: BorderRadius.circular(MalasRadius.shortcut),
                  child: SizedBox(
                    height: 56,
                    child: Icon(icon, size: 28, color: MalasColors.iconOnInk),
                  ),
                ),
              ),
              const SizedBox(height: MalasSpace.s4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: MalasText.labelChip,
              ),
              Text(
                value,
                textAlign: TextAlign.center,
                style: MalasText.bodySecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §3 attention card: highlight fill, attention stroke and lip.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.text});

  final String text;

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
            size: 20,
            color: MalasColors.borderAttentionLip,
          ),
          const SizedBox(width: MalasSpace.s12),
          Expanded(child: Text(text, style: MalasText.bodyStrong)),
        ],
      ),
    );
  }
}

/// #33, usability finding 2: a new owner is walked through one spoken sale,
/// from Bicara to the draft to Beranda. The steps are the second exception to
/// the labels-only rule in `CLAUDE.md`.
const List<String> guidedEntrySteps = [
  'Ketuk Bicara',
  'Ucapkan satu penjualan, misalnya "Jual 2 nasi goreng, 30 ribu"',
  'Cek catatannya, lalu ketuk Simpan',
];

class _GuidedEntryCard extends StatelessWidget {
  const _GuidedEntryCard({required this.onLewati});

  final VoidCallback onLewati;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catat penjualan pertama', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (index, step) in guidedEntrySteps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${index + 1}. $step'),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onLewati,
                child: const Text('Lewati'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
