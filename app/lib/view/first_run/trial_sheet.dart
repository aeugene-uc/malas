import 'package:flutter/material.dart';

import '../../model/account.dart';
import '../format.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';

/// The one sheet on the first open after day 14 (§8.11, §18), also shown
/// when a free owner asks Tanya. It returns the plan the owner picked. No
/// record is ever locked, whatever they pick.
Future<Plan> showTrialSheet(
  BuildContext context, {
  String title = 'Masa coba selesai',
}) async {
  final chosenPlan = await showModalBottomSheet<Plan>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    // Three plans and two buttons are taller than the default half-screen
    // sheet on small phones, which would push the buttons off screen.
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    backgroundColor: MalasColors.bgBrand,
    builder: (context) => _TrialSheet(title: title),
  );
  return chosenPlan ?? Plan.gratis;
}

/// DESIGN.md §3 full-brand moment: bg/brand surface, stacked circles emblem,
/// bottom hills, white-on-brand primary button and text button on brand.
class _TrialSheet extends StatelessWidget {
  const _TrialSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: MalasColors.bgBrand,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _FullBrandHillsPainter()),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s12,
              MalasSpace.screen,
              MalasSpace.s20 + bottomInset,
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
                      color: MalasColors.decoTerang,
                      borderRadius: BorderRadius.circular(MalasRadius.xs),
                    ),
                  ),
                ),
                const SizedBox(height: MalasSpace.s20),
                const Center(child: _StackedCirclesEmblem()),
                const SizedBox(height: MalasSpace.s16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: MalasText.titleScreen.copyWith(
                    color: MalasColors.textOnBrand,
                  ),
                ),
                const SizedBox(height: MalasSpace.s20),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, (name, monthlyPrice, aiReads))
                          in const [
                            ('Gratis', 0, '5 baca AI sebulan'),
                            ('Pro', 25000, '300 baca AI sebulan, Tanya'),
                            ('Pro Plus', 50000, '1.000 baca AI sebulan, Tanya'),
                          ].indexed) ...[
                        if (index > 0)
                          const Divider(indent: MalasSpace.s16),
                        _PlanRow(
                          name: name,
                          aiReads: aiReads,
                          monthlyPrice: monthlyPrice,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: MalasSpace.s20),
                LipButton(
                  label: 'Pilih Pro',
                  variant: LipVariant.onBrand,
                  onPressed: () => Navigator.of(context).pop(Plan.pro),
                ),
                const SizedBox(height: MalasSpace.s8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: MalasColors.textOnBrand,
                    minimumSize: const Size(0, MalasSize.touch),
                  ),
                  onPressed: () => Navigator.of(context).pop(Plan.gratis),
                  child: const Text('Lanjut Gratis'),
                ),
                // Keeps the bottom hills (54dp max peak) clear of the button
                // text (DESIGN.md §1.1, §10).
                const SizedBox(height: MalasSpace.s56),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// DESIGN.md §3: 3 stacked circles from dark outside to light inside:
/// brand-pressed, deco/terang, brand-soft.
class _StackedCirclesEmblem extends StatelessWidget {
  const _StackedCirclesEmblem();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: _outerCircleSize,
        height: _outerCircleSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: MalasColors.bgBrandPressed,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: _midCircleSize,
          height: _midCircleSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: MalasColors.decoTerang,
            shape: BoxShape.circle,
          ),
          child: Container(
            width: _innerCircleSize,
            height: _innerCircleSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: MalasColors.bgBrandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              MalasIcons.sparkle,
              size: _emblemIconSize,
              color: MalasColors.iconBrand,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.name,
    required this.aiReads,
    required this.monthlyPrice,
  });

  final String name;
  final String aiReads;
  final int monthlyPrice;

  @override
  Widget build(BuildContext context) {
    final priceLabel = monthlyPrice == 0
        ? formatRupiah(0)
        : '${formatRupiah(monthlyPrice)}/bulan';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MalasSize.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MalasSpace.s16,
          vertical: MalasSpace.s12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: MalasText.titleItem),
                  Text(aiReads, style: MalasText.bodySecondary),
                ],
              ),
            ),
            const SizedBox(width: MalasSpace.s12),
            Semantics(
              container: true,
              label: priceLabel,
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  MoneyText(monthlyPrice),
                  if (monthlyPrice > 0)
                    Text('/bulan', style: MalasText.bodySecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DESIGN.md §5.1 full-brand bottom hills: deco/terang, bg/brand-pressed, then
/// deco/gelap-2 as the nearest layer.
class _FullBrandHillsPainter extends CustomPainter {
  const _FullBrandHillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360;
    final dy = size.height - MalasSize.headerHeight;
    Path hill(List<double> p) {
      Offset at(int i) => Offset(p[i] * sx, p[i + 1] + dy);
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

    void fill(Path path, Color color) =>
        canvas.drawPath(path, Paint()..color = color);
    fill(
      hill([0, 234, 60, 208, 130, 238, 200, 222, 260, 208, 320, 234, 360, 216]),
      MalasColors.decoTerang,
    );
    fill(
      hill([0, 246, 70, 222, 150, 250, 220, 236, 280, 224, 330, 244, 360, 230]),
      MalasColors.bgBrandPressed,
    );
    fill(
      hill([0, 256, 80, 240, 160, 260, 240, 248, 290, 240, 330, 254, 360, 246]),
      MalasColors.decoGelap2,
    );
  }

  @override
  bool shouldRepaint(_FullBrandHillsPainter oldDelegate) => false;
}

const _handleWidth = 40.0;
const _handleHeight = 5.0;
const _outerCircleSize = 96.0;
const _midCircleSize = 72.0;
const _innerCircleSize = 48.0;
const _emblemIconSize = 24.0;
