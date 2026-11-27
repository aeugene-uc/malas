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
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';

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
    final isMasuk = viewModel.direction == Direction.masuk;
    final amountColor = isMasuk
        ? MalasColors.textMasuk
        : MalasColors.textPrimary;
    const underline = UnderlineInputBorder(
      borderSide: BorderSide(
        color: MalasColors.bgBrand,
        width: MalasSize.cardStroke,
      ),
    );
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // §5.4: a form keeps only the header hills; the action hides the
          // coins.
          BrandHeader(
            title: 'Ketik',
            height: _formHeaderHeight,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedSelector(
                  labels: const ['Masuk', 'Keluar'],
                  selectedIndex: isMasuk ? 0 : 1,
                  onSelected: (index) => viewModel.selectDirection(
                    index == 0 ? Direction.masuk : Direction.keluar,
                  ),
                ),
                const SizedBox(height: MalasSpace.s24),
                Text('Jumlah', style: MalasText.bodySecondary),
                const SizedBox(height: MalasSpace.s8),
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahInputFormatter()],
                  style: MalasText.moneyHero.copyWith(color: amountColor),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: '0',
                    hintStyle: MalasText.moneyHero.copyWith(
                      color: MalasColors.textDisabled,
                    ),
                    prefixText: isMasuk ? '+Rp ' : '−Rp ',
                    prefixStyle: MalasText.rpHero.copyWith(color: amountColor),
                    contentPadding: const EdgeInsets.only(
                      bottom: MalasSpace.s8,
                    ),
                    border: underline,
                    enabledBorder: underline,
                    focusedBorder: underline,
                  ),
                  onChanged: (text) =>
                      viewModel.setAmount(parseRupiahInput(text)),
                ),
                if (viewModel.categoriesForDirection.isNotEmpty) ...[
                  const SizedBox(height: MalasSpace.s24),
                  Text('Kategori', style: MalasText.bodySecondary),
                  const SizedBox(height: MalasSpace.s12),
                  Wrap(
                    spacing: MalasSpace.s8,
                    runSpacing: MalasSpace.s8,
                    children: [
                      for (final category in viewModel.categoriesForDirection)
                        SelectChip(
                          label: category.name,
                          isSelected: category.id == viewModel.categoryId,
                          onPressed: () =>
                              viewModel.selectCategory(category.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: MalasColors.bgSurface,
          border: Border(
            top: BorderSide(
              color: MalasColors.borderCard,
              width: MalasSize.cardStroke,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s12,
              MalasSpace.screen,
              MalasSpace.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MalasSpace.s8),
                    child: Text(
                      errorMessage,
                      style: MalasText.bodySecondary.copyWith(
                        color: MalasColors.textError,
                      ),
                    ),
                  ),
                LipButton(
                  label: errorMessage == null ? 'Simpan' : 'Coba lagi',
                  onPressed: _buttonAction(context, viewModel),
                ),
              ],
            ),
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

const _formHeaderHeight = 150.0;
