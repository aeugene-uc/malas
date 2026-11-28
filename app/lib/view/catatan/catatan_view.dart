import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/transaction_repository.dart';
import '../../model/transaction.dart';
import '../../model/transaction_filter.dart';
import '../../viewmodel/app_shell_view_model.dart';
import '../../viewmodel/catatan_view_model.dart';
import '../format.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';
import 'entry_detail_sheet.dart';
import 'piutang_utang_view.dart';

/// Catatan (§6, DESIGN.md F1): every entry by date, search, filters, delete
/// with Batal. An entry's Ulangi and Retur open the draft screen (F3).
class CatatanView extends StatelessWidget {
  const CatatanView({super.key, this.initialFocus});

  /// Set when opened from an Analisis row, to show only its entries.
  final FilterFocus? initialFocus;

  static Route<void> route(FilterFocus focus) {
    return MaterialPageRoute(builder: (_) => CatatanView(initialFocus: focus));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CatatanViewModel(
        transactionRepository: TransactionRepository(context.read<ApiClient>()),
        initialFocus: initialFocus,
      )..load(),
      child: const _CatatanScreen(),
    );
  }
}

class _CatatanScreen extends StatefulWidget {
  const _CatatanScreen();

  @override
  State<_CatatanScreen> createState() => _CatatanScreenState();
}

class _CatatanScreenState extends State<_CatatanScreen> {
  final _searchController = TextEditingController();
  late final AppShellViewModel _appShell;

  /// The tab stays alive in the shell's IndexedStack, so entries saved or
  /// paid on Beranda only show once Catatan loads again on opening.
  @override
  void initState() {
    super.initState();
    _appShell = context.read<AppShellViewModel>()
      ..addListener(_reloadWhenOpened);
  }

  @override
  void dispose() {
    _appShell.removeListener(_reloadWhenOpened);
    _searchController.dispose();
    super.dispose();
  }

  void _reloadWhenOpened() {
    if (_appShell.selectedTab == AppTab.catatan) {
      context.read<CatatanViewModel>().load();
    }
  }

  void _clearAllFilters(CatatanViewModel viewModel) {
    final filter = viewModel.filter;
    if (filter.direction case final direction?) {
      viewModel.toggleDirection(direction);
    }
    if (filter.isUnpaidOnly) viewModel.toggleUnpaidOnly();
    if (filter.focus != null) viewModel.clearFocus();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CatatanViewModel>();
    final filter = viewModel.filter;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final subtitleDate = viewModel.transactions.isNotEmpty
        ? viewModel.transactions.first.businessDate
        : null;
    final isShowingAll =
        filter.direction == null &&
        !filter.isUnpaidOnly &&
        filter.focus == null;

    final list = NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 200) viewModel.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: viewModel.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: BrandHeader(
                title: 'Catatan',
                subtitle: _formatMonthYear(subtitleDate),
                actions: [
                  if (canPop)
                    IconButton(
                      tooltip: 'Tutup',
                      color: MalasColors.textOnBrand,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(MalasIcons.x),
                    ),
                ],
                controls: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchField(
                      controller: _searchController,
                      onSearch: viewModel.search,
                    ),
                    const SizedBox(height: MalasSpace.s12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (filter.focus case final focus?) ...[
                            _OnBrandFilterChip(
                              label: focus.name,
                              isSelected: true,
                              trailingIcon: MalasIcons.x,
                              semanticLabel: 'Hapus filter ${focus.name}',
                              onPressed: viewModel.clearFocus,
                            ),
                            const SizedBox(width: MalasSpace.s8),
                          ],
                          _OnBrandFilterChip(
                            label: 'Semua',
                            isSelected: isShowingAll,
                            onPressed: () => _clearAllFilters(viewModel),
                          ),
                          const SizedBox(width: MalasSpace.s8),
                          for (final (direction, label) in const [
                            (Direction.masuk, 'Masuk'),
                            (Direction.keluar, 'Keluar'),
                          ]) ...[
                            _OnBrandFilterChip(
                              label: label,
                              isSelected: filter.direction == direction,
                              onPressed: () =>
                                  viewModel.toggleDirection(direction),
                            ),
                            const SizedBox(width: MalasSpace.s8),
                          ],
                          _OnBrandFilterChip(
                            label: 'Belum lunas',
                            isSelected: filter.isUnpaidOnly,
                            onPressed: viewModel.toggleUnpaidOnly,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                MalasSpace.screen,
                MalasSpace.s8,
                MalasSpace.screen,
                MalasSpace.s24,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LipButton(
                      label: 'Piutang/Utang',
                      icon: MalasIcons.usersThreeFill,
                      variant: LipVariant.secondary,
                      isSmall: true,
                      onPressed: () => Navigator.of(
                        context,
                      ).push(PiutangUtangView.route()),
                    ),
                    if (viewModel.errorMessage case final message?
                        when viewModel.transactions.isNotEmpty) ...[
                      const SizedBox(height: MalasSpace.s12),
                      _ReloadErrorBanner(
                        message: message,
                        onRetry: viewModel.load,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _EntrySliver(viewModel: viewModel),
          ],
        ),
      ),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < twoPaneMinWidth) return Scaffold(body: list);
    final selected = viewModel.selectedTransaction;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: listWidthFor(screenWidth),
            child: list,
          ),
          const VerticalDivider(
            width: MalasSize.cardStroke,
            thickness: MalasSize.cardStroke,
            color: MalasColors.borderCard,
          ),
          Expanded(
            child: selected == null
                ? const SizedBox.shrink()
                : SafeArea(child: EntryDetailPane(transaction: selected)),
          ),
        ],
      ),
    );
  }
}

/// From this width (tablet, open Fold) Catatan shows the list and the
/// picked entry side by side (Figma C6) instead of a sheet.
const double twoPaneMinWidth = 600;

/// The list's width: the whole screen on a phone, half of it beside the
/// details, kept between a phone's width and a comfortable reading width.
double listWidthFor(double screenWidth) {
  if (screenWidth < twoPaneMinWidth) return screenWidth;
  return (screenWidth / 2).clamp(360, 420);
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MalasRadius.md),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: MalasText.body,
      onSubmitted: onSearch,
      // Emptying the field shows everything again, without needing the search
      // key.
      onChanged: (text) {
        if (text.trim().isEmpty) onSearch('');
      },
      decoration: InputDecoration(
        hintText: 'Cari barang atau nama',
        hintStyle: MalasText.body.copyWith(color: MalasColors.textMeta),
        filled: true,
        fillColor: MalasColors.bgSurface,
        isDense: true,
        constraints: const BoxConstraints(minHeight: MalasSize.touch),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MalasSpace.s12,
          vertical: MalasSpace.s12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        prefixIcon: const Icon(
          MalasIcons.magnifyingGlass,
          size: _searchIconSize,
          color: MalasColors.textSecondary,
        ),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(
                    MalasIcons.x,
                    size: _searchIconSize,
                    color: MalasColors.textSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onSearch('');
                  },
                ),
        ),
      ),
    );
  }
}

/// DESIGN.md §2 chip on brand: pressed violet with dark lip when idle, white
/// with deep lip when selected.
class _OnBrandFilterChip extends StatelessWidget {
  const _OnBrandFilterChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.trailingIcon,
    this.semanticLabel,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final IconData? trailingIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? MalasColors.textOnBrandAction
        : MalasColors.textOnBrand;
    final trailingIcon = this.trailingIcon;
    return Semantics(
      selected: isSelected,
      child: LipPressable(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        fill: isSelected
            ? MalasColors.bgOnBrandAction
            : MalasColors.bgBrandPressed,
        lip: isSelected ? MalasColors.borderLip : MalasColors.decoGelap2,
        borderRadius: BorderRadius.circular(MalasRadius.chip),
        child: SizedBox(
          height: MalasSize.buttonKecil,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: MalasText.labelChip.copyWith(color: foreground),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: MalasSpace.s4),
                  Icon(trailingIcon, size: _chipIconSize, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReloadErrorBanner extends StatelessWidget {
  const _ReloadErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MalasSpace.s16,
          vertical: MalasSpace.s8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: MalasText.bodySecondary.copyWith(
                  color: MalasColors.textError,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

class _EntrySliver extends StatelessWidget {
  const _EntrySliver({required this.viewModel});

  final CatatanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.transactions.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.fromLTRB(
          MalasSpace.screen,
          0,
          MalasSpace.screen,
          MalasSpace.s24,
        ),
        sliver: SliverToBoxAdapter(child: _ListSkeleton()),
      );
    }
    if (viewModel.errorMessage case final message?
        when viewModel.transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(MalasSpace.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(message, style: MalasText.body, textAlign: TextAlign.center),
              const SizedBox(height: MalasSpace.s16),
              LipButton(label: 'Coba lagi', onPressed: viewModel.load),
            ],
          ),
        ),
      );
    }
    if (viewModel.transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MalasSpace.screen),
            child: Text('Belum ada catatan', style: MalasText.bodySecondary),
          ),
        ),
      );
    }
    final groups = _groupByDate(viewModel.transactions);
    final now = DateTime.now();
    final todayIso = _isoDate(now);
    final yesterdayIso = _isoDate(DateTime(now.year, now.month, now.day - 1));
    final isCompactWidth =
        listWidthFor(MediaQuery.sizeOf(context).width) < _compactWidth;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        MalasSpace.screen,
        0,
        MalasSpace.screen,
        MalasSpace.s24,
      ),
      sliver: SliverList.builder(
        itemCount: groups.length + (viewModel.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groups.length) {
            return const Padding(
              padding: EdgeInsets.only(top: MalasSpace.s16),
              child: _SkeletonRowCard(),
            );
          }
          final group = groups[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < groups.length - 1 ? MalasSpace.s24 : 0,
            ),
            child: _DateSection(
              group: group,
              todayIso: todayIso,
              yesterdayIso: yesterdayIso,
              isCompactWidth: isCompactWidth,
            ),
          );
        },
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.group,
    required this.todayIso,
    required this.yesterdayIso,
    required this.isCompactWidth,
  });

  final _DateGroup group;
  final String todayIso;
  final String yesterdayIso;
  final bool isCompactWidth;

  @override
  Widget build(BuildContext context) {
    final dayTotal = group.entries.fold(
      0,
      (sum, entry) =>
          sum +
          (entry.direction == Direction.masuk ? entry.total : -entry.total),
    );
    final sign = dayTotal > 0
        ? MoneySign.masuk
        : dayTotal < 0
        ? MoneySign.keluar
        : MoneySign.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: _formatSectionDate(
            group.businessDate,
            todayIso: todayIso,
            yesterdayIso: yesterdayIso,
            isCompactWidth: isCompactWidth,
          ),
          trailing: MoneyText(dayTotal.abs(), sign: sign),
        ),
        RowsCard(
          rows: [
            for (final entry in group.entries)
              _DismissibleEntryRow(entry: entry),
          ],
        ),
      ],
    );
  }
}

class _DismissibleEntryRow extends StatelessWidget {
  const _DismissibleEntryRow({required this.entry});

  final Transaction entry;

  @override
  Widget build(BuildContext context) {
    final isTwoPane = MediaQuery.sizeOf(context).width >= twoPaneMinWidth;
    final isSelected =
        isTwoPane &&
        context.select<CatatanViewModel, String?>(
              (viewModel) => viewModel.selectedTransaction?.id,
            ) ==
            entry.id;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: MalasSpace.s24),
        color: MalasColors.bgErrorSoft,
        child: const Icon(MalasIcons.trash, color: MalasColors.textError),
      ),
      onDismissed: (_) => deleteWithUndo(
        viewModel: context.read<CatatanViewModel>(),
        messenger: ScaffoldMessenger.of(context),
        transaction: entry,
      ),
      child: ColoredBox(
        color: isSelected ? MalasColors.bgSelected : Colors.transparent,
        child: EntryRowFor(
          entry: entry,
          onTap: isTwoPane
              ? () => context.read<CatatanViewModel>().select(entry)
              : () => showEntryDetail(context, entry),
        ),
      ),
    );
  }
}

/// DESIGN.md §4.3: loading uses skeleton blocks at the real row sizes.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _skeletonHeaderWidth,
            height: MalasSpace.s20,
            decoration: BoxDecoration(
              color: MalasColors.bgSkeleton,
              borderRadius: BorderRadius.circular(MalasRadius.xs),
            ),
          ),
          const SizedBox(height: MalasSpace.s12),
          const RowsCard(
            rows: [_SkeletonRow(), _SkeletonRow(), _SkeletonRow()],
          ),
        ],
      ),
    );
  }
}

class _SkeletonRowCard extends StatelessWidget {
  const _SkeletonRowCard();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(child: RowsCard(rows: [_SkeletonRow()]));
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MalasSize.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: MalasSpace.s16,
          horizontal: MalasSpace.s16,
        ),
        child: Row(
          children: [
            Container(
              width: MalasSize.categoryTile,
              height: MalasSize.categoryTile,
              decoration: BoxDecoration(
                color: MalasColors.bgSkeleton,
                borderRadius: BorderRadius.circular(MalasRadius.sm),
              ),
            ),
            const SizedBox(width: MalasSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _skeletonTitleWidth,
                    height: MalasSpace.s16,
                    decoration: BoxDecoration(
                      color: MalasColors.bgSkeleton,
                      borderRadius: BorderRadius.circular(MalasRadius.xs),
                    ),
                  ),
                  const SizedBox(height: MalasSpace.s8),
                  Container(
                    width: _skeletonMetaWidth,
                    height: MalasSpace.s12,
                    decoration: BoxDecoration(
                      color: MalasColors.bgSkeleton,
                      borderRadius: BorderRadius.circular(MalasRadius.xs),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: _skeletonAmountWidth,
              height: MalasSpace.s16,
              decoration: BoxDecoration(
                color: MalasColors.bgSkeleton,
                borderRadius: BorderRadius.circular(MalasRadius.xs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deletes at once and shows "Batal" for 10 seconds (§5.2, §7.5).
Future<void> deleteWithUndo({
  required CatatanViewModel viewModel,
  required ScaffoldMessengerState messenger,
  required Transaction transaction,
}) async {
  final isDeleted = await viewModel.delete(transaction);
  if (!isDeleted) return;
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Dihapus'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Batal',
        onPressed: () => viewModel.undoDelete(transaction),
      ),
    ),
  );
}

class _DateGroup {
  const _DateGroup({required this.businessDate, required this.entries});

  final String businessDate;
  final List<Transaction> entries;
}

/// The list arrives newest first, so consecutive entries with the same date
/// share one SectionHeader and RowsCard.
List<_DateGroup> _groupByDate(List<Transaction> transactions) {
  final groups = <_DateGroup>[];
  for (final transaction in transactions) {
    if (groups.isEmpty || groups.last.businessDate != transaction.businessDate) {
      groups.add(
        _DateGroup(businessDate: transaction.businessDate, entries: []),
      );
    }
    groups.last.entries.add(transaction);
  }
  return groups;
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// DESIGN.md §8: "Hari ini, Rab 25 Nov" for today and "Kemarin, Sel 24 Nov"
/// for yesterday (shortened on < 360dp), else [formatEntryDate].
String _formatSectionDate(
  String businessDate, {
  required String todayIso,
  required String yesterdayIso,
  required bool isCompactWidth,
}) {
  final relativeLabel = businessDate == todayIso
      ? 'Hari ini'
      : businessDate == yesterdayIso
      ? 'Kemarin'
      : null;
  if (relativeLabel == null) return formatEntryDate(businessDate);
  if (isCompactWidth) return relativeLabel;
  final date = DateTime.parse(businessDate);
  final weekday = formatWeekdayShort(businessDate);
  final month = _monthShortNames[date.month - 1];
  return '$relativeLabel, $weekday ${date.day} $month';
}

/// "November 2026" for the header subtitle.
String _formatMonthYear(String? businessDate) {
  final date = businessDate == null
      ? DateTime.now()
      : DateTime.parse(businessDate);
  return '${_monthFullNames[date.month - 1]} ${date.year}';
}

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

const _monthFullNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _searchIconSize = 20.0;
const _chipIconSize = 20.0;
const _compactWidth = 360.0;
const _skeletonHeaderWidth = 140.0;
const _skeletonTitleWidth = 120.0;
const _skeletonMetaWidth = 80.0;
const _skeletonAmountWidth = 72.0;
