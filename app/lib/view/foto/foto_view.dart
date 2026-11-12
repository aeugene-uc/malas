import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/draft_repository.dart';
import '../../model/draft.dart';
import '../../viewmodel/foto_view_model.dart';

/// Opened from Beranda's Foto button. Pops with the [AiReadResult], which the
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
    return Scaffold(
      appBar: AppBar(title: const Text('Foto')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PhotoKind>(
                segments: const [
                  ButtonSegment(value: PhotoKind.nota, label: Text('Nota')),
                  ButtonSegment(
                    value: PhotoKind.bukuCatatan,
                    label: Text('Buku catatan'),
                  ),
                ],
                selected: {viewModel.kind},
                onSelectionChanged: (kinds) =>
                    viewModel.selectKind(kinds.single),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (viewModel.imageBytes) {
                  final imageBytes? => Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  ),
                  null => const SizedBox.shrink(),
                },
              ),
              if (viewModel.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
    const pickButtonSize = Size(0, 72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: pickButtonSize),
                onPressed: () => viewModel.pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: pickButtonSize),
                onPressed: () => viewModel.pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeri'),
              ),
            ),
          ],
        ),
        if (viewModel.hasImage) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () => _readAndClose(context),
            child: Text(viewModel.errorMessage == null ? 'Baca' : 'Coba lagi'),
          ),
        ],
      ],
    );
  }

  Future<void> _readAndClose(BuildContext context) async {
    final readResult = await viewModel.read();
    if (readResult != null && context.mounted) {
      Navigator.of(context).pop(readResult);
    }
  }
}

class _ReadingIndicator extends StatelessWidget {
  const _ReadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(dimension: 24, child: CircularProgressIndicator()),
          SizedBox(width: 12),
          Text('Membaca…'),
        ],
      ),
    );
  }
}
