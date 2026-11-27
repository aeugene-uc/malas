import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/draft_repository.dart';
import '../../model/draft.dart';
import '../../viewmodel/foto_view_model.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';

/// Opened from the hold menu's Foto. Pops with the [AiReadResult], which the
/// draft screen opens.
class FotoView extends StatelessWidget {
  const FotoView({super.key});

  static Route<AiReadResult> route() {
    return MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (_) => FotoViewModel(
          imagePicker: ImagePicker(),
          draftRepository: context.read<DraftRepository>(),
        ),
        child: const FotoView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FotoViewModel>();
    final imageBytes = viewModel.imageBytes;
    final errorMessage = viewModel.errorMessage;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // §5.4: a form keeps only the header hills; the action hides the
          // coins.
          BrandHeader(
            title: 'Foto',
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
                Row(
                  children: [
                    for (final (index, kind) in PhotoKind.values.indexed) ...[
                      if (index > 0) const SizedBox(width: MalasSpace.s8),
                      Expanded(
                        child: SelectChip(
                          label: kind == PhotoKind.nota
                              ? 'Nota'
                              : 'Buku catatan',
                          isSelected: viewModel.kind == kind,
                          onPressed: () => viewModel.selectKind(kind),
                        ),
                      ),
                    ],
                  ],
                ),
                if (imageBytes != null) ...[
                  const SizedBox(height: MalasSpace.s16),
                  // A flat card (§2): the photo is information.
                  Container(
                    height: _previewHeight,
                    decoration: BoxDecoration(
                      color: MalasColors.bgSurface,
                      borderRadius: BorderRadius.circular(MalasRadius.lg),
                      border: Border.all(
                        color: MalasColors.borderCard,
                        width: MalasSize.cardStroke,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(imageBytes, fit: BoxFit.contain),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MalasSpace.screen,
            MalasSpace.s8,
            MalasSpace.screen,
            MalasSpace.s12,
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
              if (viewModel.isReading)
                const _ReadingIndicator()
              else
                _Controls(viewModel: viewModel),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.viewModel});

  final FotoViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: LipButton(
                label: 'Kamera',
                icon: MalasIcons.camera,
                variant: LipVariant.secondary,
                onPressed: () => viewModel.pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: MalasSpace.s12),
            Expanded(
              child: LipButton(
                label: 'Galeri',
                icon: MalasIcons.image,
                variant: LipVariant.secondary,
                onPressed: () => viewModel.pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (viewModel.hasImage) ...[
          const SizedBox(height: MalasSpace.s12),
          LipButton(
            label: viewModel.errorMessage == null ? 'Baca' : 'Coba lagi',
            onPressed: () => _readAndClose(context),
          ),
        ],
      ],
    );
  }

  /// These controls are swapped for the reading indicator while the read
  /// runs, so the navigator is taken before waiting, not from this context.
  Future<void> _readAndClose(BuildContext context) async {
    final navigator = Navigator.of(context);
    final readResult = await viewModel.read();
    if (readResult != null && navigator.mounted) navigator.pop(readResult);
  }
}

class _ReadingIndicator extends StatelessWidget {
  const _ReadingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MalasSize.buttonBesar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: MalasSpace.s24,
            child: CircularProgressIndicator(),
          ),
          const SizedBox(width: MalasSpace.s12),
          Text('Membaca…', style: MalasText.bodyStrong),
        ],
      ),
    );
  }
}

const _formHeaderHeight = 150.0;
const _previewHeight = 320.0;
