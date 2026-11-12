import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/draft_repository.dart';
import '../../model/draft.dart';
import '../../viewmodel/bicara_view_model.dart';

/// Opened from Beranda's Bicara button. Pops with the [AiReadResult], which
/// the draft screen opens.
class BicaraView extends StatelessWidget {
  const BicaraView({super.key});

  static Route<AiReadResult> route() {
    return MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (_) => BicaraViewModel(
          speech: SpeechToText(),
          draftRepository: context.read<DraftRepository>(),
        ),
        child: const BicaraView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BicaraViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bicara')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final part in viewModel.transcriptParts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        part,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                ],
              ),
            ),
            if (viewModel.errorMessage case final message?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: viewModel.isReading
                  ? const _ReadingIndicator()
                  : _Controls(viewModel: viewModel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.viewModel});

  final BicaraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isReadable = viewModel.hasTranscript && !viewModel.isListening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MicButton(viewModel: viewModel),
        if (isReadable) ...[
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

class _MicButton extends StatelessWidget {
  const _MicButton({required this.viewModel});

  final BicaraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isListening) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 72)),
        onPressed: viewModel.stopListening,
        icon: const Icon(Icons.stop),
        label: const Text('Berhenti'),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 72)),
      onPressed: viewModel.startListening,
      icon: const Icon(Icons.mic),
      label: Text(viewModel.hasTranscript ? 'Tambah' : 'Mulai'),
    );
  }
}

class _ReadingIndicator extends StatelessWidget {
  const _ReadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(dimension: 24, child: CircularProgressIndicator()),
        SizedBox(width: 12),
        Text('Membaca…'),
      ],
    );
  }
}
