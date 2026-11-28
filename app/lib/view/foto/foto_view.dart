import 'dart:typed_data';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Expanded(
            child: Padding(
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
                    labels: const ['Nota', 'Buku catatan'],
                    selectedIndex: viewModel.kind == PhotoKind.nota ? 0 : 1,
                    onSelected: (index) => viewModel.selectKind(
                      index == 0 ? PhotoKind.nota : PhotoKind.bukuCatatan,
                    ),
                  ),
                  const SizedBox(height: MalasSpace.s24),
                  Expanded(
                    child: imageBytes == null
                        ? const _EmptyPhotoCard()
                        : _PhotoPreviewCard(imageBytes: imageBytes),
                  ),
                ],
              ),
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
                if (viewModel.isReading)
                  const _ReadingIndicator()
                else
                  _Controls(viewModel: viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPhotoCard extends StatelessWidget {
  const _EmptyPhotoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MalasColors.bgBrandSoft,
        borderRadius: BorderRadius.circular(MalasRadius.lg),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(MalasSpace.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            MalasIcons.cameraFill,
            size: _emptyCameraIconSize,
            color: MalasColors.iconBrand,
          ),
          const SizedBox(height: MalasSpace.s12),
          Text('Belum ada foto', style: MalasText.bodySecondary),
        ],
      ),
    );
  }
}

class _PhotoPreviewCard extends StatelessWidget {
  const _PhotoPreviewCard({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    // A flat card (§2): the photo is information.
    return Container(
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
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.viewModel});

  final FotoViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LipButton(
            label: 'Kamera',
            icon: MalasIcons.camera,
            onPressed: () => viewModel.pickImage(ImageSource.camera),
          ),
          const SizedBox(height: MalasSpace.s12),
          LipButton(
            label: 'Galeri',
            icon: MalasIcons.image,
            variant: LipVariant.secondary,
            onPressed: () => viewModel.pickImage(ImageSource.gallery),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LipButton(
          label: viewModel.errorMessage == null ? 'Baca' : 'Coba lagi',
          onPressed: () => _readAndClose(context),
        ),
        const SizedBox(height: MalasSpace.s12),
        Row(
          children: [
            Expanded(
              child: LipButton(
                label: 'Kamera',
                icon: MalasIcons.camera,
                variant: LipVariant.secondary,
                isSmall: true,
                onPressed: () => viewModel.pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: MalasSpace.s12),
            Expanded(
              child: LipButton(
                label: 'Galeri',
                icon: MalasIcons.image,
                variant: LipVariant.secondary,
                isSmall: true,
                onPressed: () => viewModel.pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
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
const _emptyCameraIconSize = 48.0;
