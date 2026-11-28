import 'package:flutter/material.dart';

import 'tokens.dart';

/// §3 Kepala: brand block with title, optional subtitle and controls, and the
/// §5 scenery (hills, coins, sparkles) behind it. Its bottom edge is the
/// white Tanah hill, so the body below reads as the same surface.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.controls,
    this.actions = const [],
    this.height = MalasSize.headerHeight,
  });

  final String title;
  final String? subtitle;

  /// Search, chips or the day's totals. Must end above the far hill (§5.1).
  final Widget? controls;

  /// Icon buttons at the top right, e.g. Pengaturan.
  final List<Widget> actions;

  /// Below the status bar.
  final double height;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final subtitle = this.subtitle;
    final controls = this.controls;
    return SizedBox(
      height: height + topInset,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: MalasColors.bgBrand)),
          Positioned.fill(
            top: topInset,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _SceneryPainter(
                  hasCoins: actions.isEmpty,
                  hasSmallCoin: controls == null,
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: EdgeInsets.fromLTRB(
                sidePaddingFor(constraints.maxWidth),
                topInset + MalasSpace.s20,
                sidePaddingFor(constraints.maxWidth),
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MalasText.titleScreen.copyWith(
                                color: MalasColors.textOnBrand,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: MalasText.bodySecondary.copyWith(
                                  color: MalasColors.textOnBrandSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  if (controls != null) ...[
                    const SizedBox(height: MalasSpace.s16),
                    controls,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// §5.1 hill paths, authored for a 360 × 262 header: x scales with width,
/// y shifts with height.
class _SceneryPainter extends CustomPainter {
  const _SceneryPainter({required this.hasCoins, required this.hasSmallCoin});

  final bool hasCoins;

  /// The small coin sits where controls start, so it's left out with them.
  final bool hasSmallCoin;

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
    if (hasCoins) {
      _coin(canvas, Offset(286 * sx, 36), 46);
      if (hasSmallCoin) _coin(canvas, Offset(246 * sx, 70), 28);
      _sparkle(canvas, Offset(222 * sx, 40), 12, MalasColors.textOnBrand);
      _sparkle(canvas, Offset(334 * sx, 92), 10, MalasColors.decoTerang);
    }
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
      MalasColors.bgGround,
    );
  }

  /// §5.2 coin: jeruk disc on its lip, with an inner ring at 62%.
  void _coin(Canvas canvas, Offset topLeft, double d) {
    final lip = (d / 10).clamp(2, double.infinity).toDouble();
    final center = topLeft + Offset(d / 2, d / 2);
    canvas.drawCircle(
      center + Offset(0, lip),
      d / 2,
      Paint()..color = MalasColors.jerukLip,
    );
    canvas.drawCircle(center, d / 2, Paint()..color = MalasColors.jeruk);
    canvas.drawCircle(
      center,
      d * 0.31,
      Paint()
        ..color = MalasColors.jerukLip
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// §5.2 4-point sparkle.
  void _sparkle(Canvas canvas, Offset o, double d, Color color) {
    final h = d / 2;
    final q = 0.38 * d;
    final path = Path()
      ..moveTo(o.dx + h, o.dy)
      ..cubicTo(o.dx + h, o.dy + q, o.dx + d - q, o.dy + h, o.dx + d, o.dy + h)
      ..cubicTo(
        o.dx + d - q,
        o.dy + h,
        o.dx + h,
        o.dy + d - q,
        o.dx + h,
        o.dy + d,
      )
      ..cubicTo(o.dx + h, o.dy + d - q, o.dx + q, o.dy + h, o.dx, o.dy + h)
      ..cubicTo(o.dx + q, o.dy + h, o.dx + h, o.dy + q, o.dx + h, o.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SceneryPainter oldDelegate) =>
      oldDelegate.hasCoins != hasCoins ||
      oldDelegate.hasSmallCoin != hasSmallCoin;
}
