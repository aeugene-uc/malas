import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store_repository.dart';
import '../../model/item.dart';
import '../../viewmodel/items_view_model.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';

class ItemsView extends StatelessWidget {
  const ItemsView({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) =>
            ItemsViewModel(storeRepository: context.read<StoreRepository>())
              ..load(),
        child: const ItemsView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ItemsViewModel>();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // §5.4: a form keeps only the header hills; the action hides the
          // coins.
          BrandHeader(
            title: 'Barang dan satuan',
            actions: [
              IconButton(
                tooltip: 'Tutup',
                color: MalasColors.textOnBrand,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(MalasIcons.x),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s8,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: switch (viewModel) {
              ItemsViewModel(isLoading: true) => const _Skeleton(),
              ItemsViewModel(items: [], errorMessage: final message?) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: MalasText.body,
                  ),
                  const SizedBox(height: MalasSpace.s16),
                  LipButton(label: 'Coba lagi', onPressed: viewModel.load),
                ],
              ),
              _ => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, kind) in ItemKind.values.indexed) ...[
                    if (index > 0) const SizedBox(height: MalasSpace.s24),
                    _ItemSection(
                      kind: kind,
                      items: [
                        for (final item in viewModel.items)
                          if (item.kind == kind) item,
                      ],
                      onEdit: (item) => _edit(context, item),
                    ),
                  ],
                ],
              ),
            },
          ),
        ],
      ),
    );
  }

  /// §4.2: a sheet instead of a dialog.
  Future<void> _edit(BuildContext context, Item item) {
    final viewModel = context.read<ItemsViewModel>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: _ItemSheet(item: item),
      ),
    );
  }
}

/// §4.3: skeleton blocks at row size instead of a spinner.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _skeletonRowCount; index++)
          Container(
            height: MalasSize.row,
            margin: const EdgeInsets.only(bottom: MalasSpace.s12),
            decoration: BoxDecoration(
              color: MalasColors.bgSkeleton,
              borderRadius: BorderRadius.circular(MalasRadius.lg),
            ),
          ),
      ],
    );
  }
}

class _ItemSection extends StatelessWidget {
  const _ItemSection({
    required this.kind,
    required this.items,
    required this.onEdit,
  });

  final ItemKind kind;
  final List<Item> items;
  final ValueChanged<Item> onEdit;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (kind) {
      ItemKind.dijual => (CategoryTone.penjualan, MalasIcons.storefrontFill),
      ItemKind.dibeli => (CategoryTone.bahan, MalasIcons.basketFill),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: kind.label),
        if (items.isNotEmpty)
          RowsCard(
            rows: [
              for (final item in items)
                EntryRow(
                  title: item.name,
                  meta: item.unit,
                  tone: tone,
                  icon: icon,
                  money: switch (item.savedPrice) {
                    final price? => MoneyText(price),
                    null => Text(
                      'harga belum ada',
                      style: MalasText.bodySecondary,
                    ),
                  },
                  onTap: () => onEdit(item),
                ),
            ],
          ),
      ],
    );
  }
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.item});

  final Item item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _nameController = TextEditingController(text: widget.item.name);
  late final _priceController = TextEditingController(
    text: widget.item.savedPrice?.toString() ?? '',
  );
  late String? _unit = widget.item.unit;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = context.watch<ItemsViewModel>().errorMessage;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          MalasSpace.screen,
          MalasSpace.s12,
          MalasSpace.screen,
          MalasSpace.s20 + keyboardHeight,
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
            const SizedBox(height: MalasSpace.s20),
            Text('Ubah', style: MalasText.titleScreen),
            const SizedBox(height: MalasSpace.s16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: MalasSpace.s16),
            DropdownButtonFormField<String?>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Satuan'),
              icon: const Icon(MalasIcons.caretDown, size: 20),
              onChanged: (unit) => setState(() => _unit = unit),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (final unit in units)
                  DropdownMenuItem(value: unit, child: Text(unit)),
              ],
            ),
            const SizedBox(height: MalasSpace.s16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: MalasText.moneyRow,
              decoration: const InputDecoration(
                labelText: 'Harga',
                prefixText: 'Rp ',
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: MalasSpace.s12),
              Text(
                errorMessage,
                style: MalasText.bodySecondary.copyWith(
                  color: MalasColors.textError,
                ),
              ),
            ],
            const SizedBox(height: MalasSpace.s24),
            LipButton(label: 'Simpan', onPressed: _isSaving ? null : _save),
            const SizedBox(height: MalasSpace.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    final isSaved = await context.read<ItemsViewModel>().saveItem(
      item: widget.item,
      name: _nameController.text,
      unit: _unit,
      priceText: _priceController.text,
    );
    if (isSaved) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

const _skeletonRowCount = 3;

/// §4.2 sheet handle.
const _handleWidth = 40.0;
const _handleHeight = 5.0;
