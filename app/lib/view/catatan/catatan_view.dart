import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/transaction_repository.dart';
import '../../model/transaction.dart';
import '../../model/transaction_filter.dart';
import '../../viewmodel/catatan_view_model.dart';
import '../format.dart';
import 'entry_detail_sheet.dart';
import 'piutang_utang_view.dart';

/// Catatan (§6): every entry by date, search, filters, delete with Batal.
/// An entry's Ulangi and Retur open the draft screen (F3).
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CatatanViewModel>();
    final filter = viewModel.filter;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).push(PiutangUtangView.route()),
            child: const Text('Piutang/Utang'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: viewModel.search,
              // Emptying the field shows everything again, without needing
              // the search key.
              onChanged: (text) {
                if (text.trim().isEmpty) viewModel.search('');
              },
              decoration: InputDecoration(
                labelText: 'Cari',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            viewModel.search('');
                          },
                        ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (filter.focus case final focus?) ...[
                  InputChip(
                    label: Text(focus.name),
                    onDeleted: viewModel.clearFocus,
                  ),
                  const SizedBox(width: 8),
                ],
                for (final (direction, label) in const [
                  (Direction.masuk, 'Masuk'),
                  (Direction.keluar, 'Keluar'),
                ]) ...[
                  FilterChip(
                    label: Text(label),
                    selected: filter.direction == direction,
                    onSelected: (_) => viewModel.toggleDirection(direction),
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  label: const Text('Belum lunas'),
                  selected: filter.isUnpaidOnly,
                  onSelected: (_) => viewModel.toggleUnpaidOnly(),
                ),
              ],
            ),
          ),
          Expanded(child: _EntryList(viewModel: viewModel)),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.viewModel});

  final CatatanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.errorMessage case final message?
        when viewModel.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: viewModel.load,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (viewModel.transactions.isEmpty) {
      return const Center(child: Text('Belum ada catatan'));
    }
    final rows = _rowsByDate(viewModel.transactions);
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 200) viewModel.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView.builder(
          itemCount: rows.length + (viewModel.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return switch (rows[index]) {
              _DateHeader(:final businessDate) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  formatEntryDate(businessDate),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _EntryRow(:final transaction) => _EntryTile(
                transaction: transaction,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isMasuk = transaction.direction == Direction.masuk;
    final tags = [
      if (!transaction.isFullyPaid)
        'Belum lunas ${formatRupiah(transaction.remaining)}',
      if (transaction.editCount > 0) 'Diubah ${transaction.editCount}x',
      if (transaction.hasRetur) 'Ada retur',
    ];
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => deleteWithUndo(
        viewModel: context.read<CatatanViewModel>(),
        messenger: ScaffoldMessenger.of(context),
        transaction: transaction,
      ),
      child: ListTile(
        leading: Icon(isMasuk ? Icons.south_west : Icons.north_east),
        title: Text(describeEntry(transaction)),
        subtitle: tags.isEmpty ? null : Text(tags.join(' · ')),
        trailing: Text(formatEntryTotal(transaction)),
        onTap: () => showEntryDetail(context, transaction),
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

/// "Min, 15 Nov".
String formatEntryDate(String businessDate) {
  const monthShortNames = [
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
  final date = DateTime.parse(businessDate);
  final weekday = formatWeekdayShort(businessDate);
  return '$weekday, ${date.day} ${monthShortNames[date.month - 1]}';
}

sealed class _Row {
  const _Row();
}

class _DateHeader extends _Row {
  const _DateHeader(this.businessDate);

  final String businessDate;
}

class _EntryRow extends _Row {
  const _EntryRow(this.transaction);

  final Transaction transaction;
}

/// The list arrives newest first, so a header goes before each new date.
List<_Row> _rowsByDate(List<Transaction> transactions) {
  final rows = <_Row>[];
  String? currentDate;
  for (final transaction in transactions) {
    if (transaction.businessDate != currentDate) {
      currentDate = transaction.businessDate;
      rows.add(_DateHeader(currentDate));
    }
    rows.add(_EntryRow(transaction));
  }
  return rows;
}
