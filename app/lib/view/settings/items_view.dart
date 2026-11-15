import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store_repository.dart';
import '../../model/item.dart';
import '../../viewmodel/items_view_model.dart';
import '../format.dart';

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
      appBar: AppBar(title: const Text('Barang dan satuan')),
      body: switch (viewModel) {
        ItemsViewModel(isLoading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        ItemsViewModel(items: [], errorMessage: final message?) => Center(
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
        ),
        _ => ListView(
          children: [
            for (final kind in ItemKind.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  kind.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final item in viewModel.items.where((i) => i.kind == kind))
                ListTile(
                  title: Text(item.name),
                  subtitle: item.unit == null ? null : Text(item.unit!),
                  trailing: Text(
                    item.savedPrice == null
                        ? 'harga belum ada'
                        : formatRupiah(item.savedPrice!),
                  ),
                  onTap: () => _edit(context, item),
                ),
            ],
          ],
        ),
      },
    );
  }

  Future<void> _edit(BuildContext context, Item item) {
    final viewModel = context.read<ItemsViewModel>();
    return showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: _ItemDialog(item: item),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.item});

  final Item item;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
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
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Satuan'),
              onChanged: (unit) => setState(() => _unit = unit),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (final unit in units)
                  DropdownMenuItem(value: unit, child: Text(unit)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga',
                prefixText: 'Rp ',
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
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
