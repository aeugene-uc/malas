import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/draft_repository.dart';
import '../../model/draft.dart';
import '../../viewmodel/app_shell_view_model.dart';
import '../../viewmodel/bicara_view_model.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/tokens.dart';

/// Opened from the nav mic. Pops with the [AiReadResult], which the draft
/// screen opens.
class BicaraView extends StatelessWidget {
  const BicaraView({super.key});

  /// §4.1 F3: the record panel floats over the dimmed screen it came from.
  static Route<AiReadResult> route() {
    return PageRouteBuilder(
      opaque: false,
      barrierColor: MalasColors.scrim,
      transitionDuration: _panelMotion,
      reverseTransitionDuration: _panelMotion,
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: AnimatedBuilder(
            animation: curved,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, MalasSpace.s24 * (1 - curved.value)),
              child: child,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, _) => ChangeNotifierProvider(
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _panelWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                MalasSpace.s12,
                MalasSpace.s12,
                MalasSpace.s12,
                MalasSize.navBar + MalasSpace.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RecordPanel(viewModel: viewModel),
                  if (!viewModel.isReading) ...[
                    const SizedBox(height: MalasSpace.s16),
                    _Controls(viewModel: viewModel),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// F3 record panel: brand fill on a lip (§2's one information exception),
/// status row, live transcript, wave, two hills along the bottom.
class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.viewModel});

  final BicaraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final errorMessage = viewModel.errorMessage;
    final radius = BorderRadius.circular(MalasRadius.xl);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, MalasSize.lip),
            color: MalasColors.borderLip,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: MalasColors.bgBrand,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _hillsHeight,
                child: ExcludeSemantics(
                  child: CustomPaint(painter: _PanelHillsPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MalasSpace.s20,
                  14,
                  MalasSpace.s20,
                  22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusRow(viewModel: viewModel),
                    for (final part in viewModel.transcriptParts)
                      Padding(
                        padding: const EdgeInsets.only(top: MalasSpace.s12),
                        child: Text(
                          part,
                          style: MalasText.transcript.copyWith(
                            color: MalasColors.textOnBrand,
                          ),
                        ),
                      ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: MalasSpace.s12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MalasSpace.s8,
                          vertical: MalasSpace.s4,
                        ),
                        decoration: BoxDecoration(
                          color: MalasColors.bgErrorSoft,
                          borderRadius: BorderRadius.circular(MalasRadius.xs),
                        ),
                        child: Text(
                          errorMessage,
                          style: MalasText.bodySecondary.copyWith(
                            color: MalasColors.textError,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: MalasSpace.s24),
                    const ExcludeSemantics(
                      child: SizedBox(
                        height: _waveHeight,
                        child: CustomPaint(painter: _WavePainter()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.viewModel});

  final BicaraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final status = switch (viewModel) {
      BicaraViewModel(isReading: true) => 'Membaca…',
      BicaraViewModel(isListening: true) => 'Mendengarkan',
      _ => null,
    };
    return Row(
      children: [
        if (viewModel.isListening) ...[
          Container(
            width: MalasSpace.s8,
            height: MalasSpace.s8,
            decoration: const BoxDecoration(
              color: MalasColors.jeruk,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: MalasSpace.s8),
        ],
        Expanded(
          child: Text(
            status ?? '',
            style: MalasText.labelChip.copyWith(color: MalasColors.textOnBrand),
          ),
        ),
        SizedBox.square(
          dimension: MalasSize.touch,
          child: LipPressable(
            semanticLabel: 'Tutup',
            onPressed: () => Navigator.of(context).pop(),
            fill: MalasColors.bgBrandPressed,
            lip: MalasColors.decoGelap2,
            borderRadius: BorderRadius.circular(MalasSize.touch / 2),
            child: const Icon(
              MalasIcons.x,
              size: 20,
              color: MalasColors.iconOnInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// Baca once there is something to read, then Foto, the mic and Ketik in
/// the hold menu's order, so every capture mode is a tap away (§4.1 #533).
class _Controls extends StatelessWidget {
  const _Controls({required this.viewModel});

  final BicaraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isReadable = viewModel.hasTranscript && !viewModel.isListening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isReadable) ...[
          LipButton(
            label: viewModel.errorMessage == null ? 'Baca' : 'Coba lagi',
            onPressed: () => _readAndClose(context),
          ),
          const SizedBox(height: MalasSpace.s16),
        ],
        Row(
          children: [
            Expanded(
              child: LipButton(
                label: 'Foto',
                icon: MalasIcons.camera,
                variant: LipVariant.secondary,
                isSmall: true,
                onPressed: () => _switchTo(context, CaptureMode.foto),
              ),
            ),
            const SizedBox(width: MalasSpace.s16),
            _MicButton(viewModel: viewModel),
            const SizedBox(width: MalasSpace.s16),
            Expanded(
              child: LipButton(
                label: 'Ketik',
                icon: MalasIcons.keyboard,
                variant: LipVariant.secondary,
                isSmall: true,
                onPressed: () => _switchTo(context, CaptureMode.ketik),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// These controls are swapped for the reading status while the read runs,
  /// so the navigator is taken before waiting, not from this context.
  Future<void> _readAndClose(BuildContext context) async {
    final navigator = Navigator.of(context);
    final readResult = await viewModel.read();
    if (readResult != null && navigator.mounted) navigator.pop(readResult);
  }

  /// Closes Bicara with nothing read and lets Beranda open the other mode.
  void _switchTo(BuildContext context, CaptureMode mode) {
    final appShell = context.read<AppShellViewModel>();
    Navigator.of(context).pop();
    appShell.requestCapture(mode);
  }
}

/// §2 nav mic / stop: round brand fill on the lip, labelled under it.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.viewModel});

  final BicaraViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isListening = viewModel.isListening;
    final label = isListening
        ? 'Berhenti'
        : (viewModel.hasTranscript ? 'Tambah' : 'Mulai');
    final onPressed = isListening
        ? viewModel.stopListening
        : viewModel.startListening;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: MalasSize.navMic,
          child: LipPressable(
            semanticLabel: label,
            onPressed: onPressed,
            fill: MalasColors.bgBrand,
            lip: MalasColors.borderLip,
            borderRadius: BorderRadius.circular(MalasSize.navMic / 2),
            child: SizedBox(
              height: MalasSize.navMic,
              child: Icon(
                isListening ? MalasIcons.stopFill : MalasIcons.microphoneFill,
                size: 28,
                color: MalasColors.iconOnInk,
              ),
            ),
          ),
        ),
        // A white pill keeps the label readable on the scrim, as in the
        // hold menu.
        ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s8),
            decoration: BoxDecoration(
              color: MalasColors.bgSurface,
              borderRadius: BorderRadius.circular(MalasRadius.xs),
            ),
            child: Text(label, style: MalasText.labelTag),
          ),
        ),
      ],
    );
  }
}

/// §5.1 record panel: two hill layers along the bottom edge, authored for a
/// 336 × [_hillsHeight] strip.
class _PanelHillsPainter extends CustomPainter {
  const _PanelHillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _panelWidth;
    Path hill(List<double> p) {
      Offset at(int i) => Offset(p[i] * sx, p[i + 1]);
      final start = at(0);
      return Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(at(2).dx, at(2).dy, at(4).dx, at(4).dy, at(6).dx, at(6).dy)
        ..cubicTo(
          at(8).dx,
          at(8).dy,
          at(10).dx,
          at(10).dy,
          at(12).dx,
          at(12).dy,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }

    canvas.drawPath(
      hill([0, 18, 60, 0, 120, 26, 190, 12, 250, 0, 300, 22, 336, 8]),
      Paint()..color = MalasColors.bgBrandPressed,
    );
    canvas.drawPath(
      hill([0, 44, 70, 30, 150, 54, 220, 40, 280, 30, 320, 48, 336, 38]),
      Paint()..color = MalasColors.decoGelap2,
    );
  }

  @override
  bool shouldRepaint(_PanelHillsPainter oldDelegate) => false;
}

/// A still sound wave: rounded bars, tallest in the middle.
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MalasColors.textOnBrand
      ..strokeWidth = _waveBarWidth
      ..strokeCap = StrokeCap.round;
    final count = _waveLevels.length;
    final step = size.width / count;
    for (final (index, level) in _waveLevels.indexed) {
      final x = step * (index + 0.5);
      final half = size.height * level / 2;
      final midY = size.height / 2;
      canvas.drawLine(Offset(x, midY - half), Offset(x, midY + half), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

/// F3 panel width.
const _panelWidth = 336.0;
const _hillsHeight = 76.0;
const _waveHeight = 32.0;
const _waveBarWidth = 3.0;
const _waveLevels = [
  0.2, 0.4, 0.3, 0.6, 0.8, 0.5, 0.9, 1.0, 0.7, 0.9, //
  0.6, 1.0, 0.8, 0.5, 0.7, 0.4, 0.6, 0.3, 0.4, 0.2,
];

/// §6 record panel: slides up 24 and fades in over 220ms.
const _panelMotion = Duration(milliseconds: 220);
