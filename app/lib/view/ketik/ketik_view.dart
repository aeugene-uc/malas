import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/draft_repository.dart';
import '../../data/store_repository.dart';
import '../../data/unsent_drafts_store.dart';
import '../../model/transaction.dart';
import '../../viewmodel/draft_view_model.dart';
import '../../viewmodel/ketik_view_model.dart';
import '../draft/draft_view.dart';
import '../format.dart';

/// Opens Ketik. A saved amount shows the Batal toast on the caller's screen,
/// and [onChanged] runs after the save and after a Batal.
Future<void> openKetik(
  BuildContext context, {
  required String businessToday,
  required VoidCallback onChanged,
}) async {
  final savedDraft = await Navigator.of(context).push<DraftViewModel>(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (routeContext) => KetikViewModel(
          storeRepository: routeContext.read<StoreRepository>(),
          draftRepository: routeContext.read<DraftRepository>(),
          businessToday: businessToday,
          unsentDraftsStore: routeContext.read<UnsentDraftsStore>(),
        )..loadCategories(),
        child: const KetikView(),
      ),
    ),
  );
  if (savedDraft == null || !context.mounted) return;
  onChanged();
  await showBatalToast(context, viewModel: savedDraft, onChanged: onChanged);
}

class KetikView extends StatelessWidget {
  const KetikView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<KetikViewModel>();
    final errorMessage = viewModel.errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('Ketik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<Direction>(
            segments: const [
              ButtonSegment(value: Direction.masuk, label: Text('Masuk')),
              ButtonSegment(value: Direction.keluar, label: Text('Keluar')),
            ],
            selected: {viewModel.direction},
            onSelectionChanged: (selected) =>
                viewModel.selectDirection(selected.single),
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              prefixText: 'Rp ',
            ),
            onChanged: (text) => viewModel.setAmount(parseRupiahInput(text)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final category in viewModel.categoriesForDirection)
                ChoiceChip(
                  label: Text(category.name),
                  selected: category.id == viewModel.categoryId,
                  onSelected: (_) => viewModel.selectCategory(category.id),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _buttonAction(context, viewModel),
                child: Text(errorMessage == null ? 'Simpan' : 'Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _buttonAction(BuildContext context, KetikViewModel viewModel) {
    if (viewModel.isLoading) return null;
    if (viewModel.isMissingCategories) return viewModel.loadCategories;
    if (!viewModel.canSave) return null;
    return () => _simpan(context, viewModel);
  }

  Future<void> _simpan(BuildContext context, KetikViewModel viewModel) async {
    await viewModel.simpan();
    final savedDraft = viewModel.savedDraft;
    if (savedDraft != null && context.mounted) {
      Navigator.of(context).pop(savedDraft);
    }
  }
}
