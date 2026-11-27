import 'package:flutter/material.dart';

import 'tokens.dart';

/// DESIGN.md §2: everything pressable is a solid fill on a 4px lip. Pressing
/// drops the body onto the lip.
class LipPressable extends StatefulWidget {
  const LipPressable({
    super.key,
    required this.onPressed,
    required this.fill,
    required this.lip,
    required this.borderRadius,
    required this.child,
    this.onLongPress,
    this.semanticLabel,
  });

  /// Null disables it: flat, no lip, greyed.
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Color fill;
  final Color lip;
  final BorderRadius borderRadius;
  final Widget child;
  final String? semanticLabel;

  @override
  State<LipPressable> createState() => _LipPressableState();
}

class _LipPressableState extends State<LipPressable> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed != isPressed) setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final isAnimated = !MediaQuery.disableAnimationsOf(context);
    final drop = _isPressed || !isEnabled ? MalasSize.lip : 0.0;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? (_) => _setPressed(true) : null,
        onTapUp: isEnabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.only(bottom: MalasSize.lip),
          child: AnimatedContainer(
            duration: isAnimated
                ? Duration(milliseconds: _isPressed ? 80 : 120)
                : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, drop, 0),
            decoration: BoxDecoration(
              color: isEnabled ? widget.fill : MalasColors.bgSecondary,
              borderRadius: widget.borderRadius,
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, MalasSize.lip - drop),
                  color: widget.lip,
                ),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: isEnabled ? null : MalasColors.textDisabled,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// §2's button table.
enum LipVariant {
  primary(MalasColors.bgBrand, MalasColors.borderLip, MalasColors.textOnBrand),
  secondary(
    MalasColors.bgSecondary,
    MalasColors.borderLipSekunder,
    MalasColors.textPrimary,
  ),
  danger(
    MalasColors.bgSecondary,
    MalasColors.borderLipSekunder,
    MalasColors.textError,
  ),
  onBrand(
    MalasColors.bgOnBrandAction,
    MalasColors.borderLip,
    MalasColors.textOnBrandAction,
  ),
  jeruk(MalasColors.jeruk, MalasColors.jerukLip, MalasColors.textOnInk);

  const LipVariant(this.fill, this.lip, this.foreground);

  final Color fill;
  final Color lip;
  final Color foreground;
}

class LipButton extends StatelessWidget {
  const LipButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LipVariant.primary,
    this.isSmall = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final LipVariant variant;

  /// Kecil (44) instead of Besar (56).
  final bool isSmall;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return LipPressable(
      onPressed: onPressed,
      fill: variant.fill,
      lip: variant.lip,
      borderRadius: BorderRadius.circular(MalasRadius.md),
      child: SizedBox(
        height: isSmall ? MalasSize.buttonKecil : MalasSize.buttonBesar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: variant.foreground),
                const SizedBox(width: MalasSpace.s8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MalasText.labelButton.copyWith(
                    color: onPressed == null
                        ? MalasColors.textDisabled
                        : variant.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
