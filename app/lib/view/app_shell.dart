import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/app_shell_view_model.dart';
import 'analisis/analisis_view.dart';
import 'beranda/beranda_view.dart';
import 'catatan/catatan_view.dart';
import 'tanya/tanya_view.dart';
import 'theme/lip.dart';
import 'theme/tokens.dart';
import 'theme/icons.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppShellViewModel>();
    return Scaffold(
      // IndexedStack keeps each tab's scroll position and state when the
      // owner switches away and back.
      body: IndexedStack(
        index: viewModel.selectedTab.index,
        children: const [
          BerandaView(),
          CatatanView(),
          AnalisisView(),
          TanyaView(),
        ],
      ),
      bottomNavigationBar: _NavBar(viewModel: viewModel),
    );
  }
}

/// §3 Nav Bar · Tengah: two tabs, the mic, two tabs.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.viewModel});

  final AppShellViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    Widget tab(AppTab tab) => Expanded(
      child: _NavTab(
        key: ValueKey(tab),
        tab: tab,
        isSelected: viewModel.selectedTab == tab,
        onTap: () => viewModel.selectTab(tab),
      ),
    );
    return DecoratedBox(
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
        child: SizedBox(
          height: MalasSize.navBar - 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              tab(AppTab.beranda),
              tab(AppTab.catatan),
              Expanded(child: _NavMic(viewModel: viewModel)),
              tab(AppTab.analisis),
              tab(AppTab.tanya),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    super.key,
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final AppTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? MalasColors.textBrandDark
        : MalasColors.textSecondary;
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: MalasSpace.s8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? MalasColors.bgSelected : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _iconFor(tab, isSelected: isSelected),
                  size: 24,
                  color: isSelected
                      ? MalasColors.iconBrand
                      : MalasColors.textSecondary,
                ),
              ),
              const SizedBox(height: MalasSpace.s4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: MalasText.labelNav.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §4.1: tap records straight away, hold fans out Bicara, Foto and Ketik.
/// The held finger can slide onto one and let go to pick it; let go
/// anywhere else and the three stay open for a tap.
class _NavMic extends StatefulWidget {
  const _NavMic({required this.viewModel});

  final AppShellViewModel viewModel;

  @override
  State<_NavMic> createState() => _NavMicState();
}

class _NavMicState extends State<_NavMic> with SingleTickerProviderStateMixin {
  late final AnimationController _fanOut = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  _CaptureMenu? _menu;
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _menuEntry?.remove();
    _fanOut.dispose();
    super.dispose();
  }

  /// An overlay, not a route: pushing a route cancels the finger still
  /// holding the mic, and then it could not slide onto a button.
  void _open(LongPressStartDetails details) {
    if (_menuEntry != null) return;
    final menu = _CaptureMenu(onPick: _pick);
    final entry = OverlayEntry(
      builder: (_) =>
          _CaptureMenuLayer(menu: menu, animation: _fanOut, onClose: _close),
    );
    setState(() {
      _menu = menu;
      _menuEntry = entry;
    });
    Overlay.of(context, rootOverlay: true).insert(entry);
    if (MediaQuery.disableAnimationsOf(context)) {
      _fanOut.value = 1;
    } else {
      _fanOut.forward(from: 0);
    }
  }

  void _pick(_MenuOption option) {
    final mode = switch (option) {
      _MenuOption.bicara => CaptureMode.bicara,
      _MenuOption.foto => CaptureMode.foto,
      _MenuOption.ketik => CaptureMode.ketik,
      _MenuOption.tutup => null,
    };
    if (mode == null) {
      _close();
      return;
    }
    // Gone at once, so it never sits on top of the screen that opens.
    _removeMenu();
    widget.viewModel.requestCapture(mode);
  }

  Future<void> _close() async {
    final entry = _menuEntry;
    if (entry == null) return;
    await _fanOut.reverse();
    if (_menuEntry == entry) _removeMenu();
  }

  void _removeMenu() {
    _menuEntry?.remove();
    if (!mounted) return;
    setState(() {
      _menuEntry = null;
      _menu = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Back closes the menu, as it would a dialog. PopScope, not a binding
    // observer: Android 14 only hands back to an app that says it wants it.
    return PopScope(
      canPop: _menuEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: MalasSpace.s8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: MalasSize.navMic,
                  child: Tooltip(
                    message: 'Bicara',
                    excludeFromSemantics: true,
                    child: GestureDetector(
                      onLongPressStart: _open,
                      onLongPressMoveUpdate: (details) =>
                          _menu?.hoverAt(details.globalPosition),
                      onLongPressEnd: (details) =>
                          _menu?.releaseAt(details.globalPosition),
                      child: LipPressable(
                        semanticLabel: 'Bicara',
                        onPressed: () =>
                            widget.viewModel.requestCapture(CaptureMode.bicara),
                        fill: MalasColors.bgBrand,
                        lip: MalasColors.borderLip,
                        borderRadius: BorderRadius.circular(
                          MalasSize.navMic / 2,
                        ),
                        child: const SizedBox(
                          height: MalasSize.navMic,
                          child: Icon(
                            MalasIcons.microphoneFill,
                            size: 28,
                            color: MalasColors.iconOnInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text('Bicara', style: MalasText.labelNav),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuOption { bicara, foto, ketik, tutup }

/// One open capture menu: where its buttons sit on screen and which one the
/// held finger is over.
class _CaptureMenu {
  _CaptureMenu({required this.onPick});

  final void Function(_MenuOption option) onPick;
  final Map<_MenuOption, GlobalKey> keysByOption = {
    for (final option in _MenuOption.values) option: GlobalKey(),
  };
  final ValueNotifier<_MenuOption?> hovered = ValueNotifier(null);
  bool _isPicked = false;

  void hoverAt(Offset position) => hovered.value = _captureOptionAt(position);

  void releaseAt(Offset position) {
    hovered.value = null;
    final option = _captureOptionAt(position);
    if (option != null) pick(option);
  }

  /// Tutup sits where the mic is, so a finger let go without sliding lands
  /// on it; that keeps the menu open instead of closing it.
  _MenuOption? _captureOptionAt(Offset position) {
    final option = _optionAt(position);
    return option == _MenuOption.tutup ? null : option;
  }

  void pick(_MenuOption option) {
    // A double tap while it fades out must not open two captures.
    if (_isPicked) return;
    _isPicked = true;
    onPick(option);
  }

  _MenuOption? _optionAt(Offset position) {
    for (final MapEntry(key: option, value: key) in keysByOption.entries) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(position)) {
        return option;
      }
    }
    return null;
  }
}

/// One menu button's height, label included, for where it flies out from.
const double _optionHeight = MalasSize.navMic + 32;

/// How far Foto and Ketik sit to each side of the mic.
const double _optionSideReach = 48 + (MalasSize.navMic + 8) / 2;

/// §4.1 A3: three round buttons fan out of the mic over the scrim, one
/// after another, and the mic becomes Tutup.
class _CaptureMenuLayer extends StatelessWidget {
  const _CaptureMenuLayer({
    required this.menu,
    required this.animation,
    required this.onClose,
  });

  final _CaptureMenu menu;
  final Animation<double> animation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedModalBarrier(
          color: ColorTween(
            begin: Colors.transparent,
            end: MalasColors.scrim,
          ).animate(animation),
          semanticsLabel: 'Tutup',
          onDismiss: onClose,
        ),
        _buildButtons(),
      ],
    );
  }

  Widget _buildButtons() {
    Widget option(
      _MenuOption option, {
      required String label,
      required IconData icon,
      required CategoryTone? tone,
      required double startsAt,
      required Offset fromMic,
    }) {
      // Keyed outside the fly-in, so the finger is matched against where a
      // button lands, not against the mic it is still flying out of.
      return KeyedSubtree(
        key: menu.keysByOption[option],
        child: _FanIn(
          animation: animation,
          startsAt: startsAt,
          from: fromMic,
          child: ValueListenableBuilder(
            valueListenable: menu.hovered,
            builder: (_, hovered, _) => _CaptureOption(
              label: label,
              icon: icon,
              tone: tone,
              isHovered: hovered == option,
              onTap: () => menu.pick(option),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: MalasSpace.s4),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(
                  _MenuOption.bicara,
                  label: 'Bicara',
                  icon: MalasIcons.microphoneFill,
                  tone: CategoryTone.penjualan,
                  startsAt: 0.2,
                  fromMic: const Offset(0, 2 * _optionHeight + 8),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    option(
                      _MenuOption.foto,
                      label: 'Foto',
                      icon: MalasIcons.cameraFill,
                      tone: CategoryTone.minuman,
                      startsAt: 0,
                      fromMic: const Offset(
                        _optionSideReach,
                        _optionHeight + 8,
                      ),
                    ),
                    const SizedBox(width: 96),
                    option(
                      _MenuOption.ketik,
                      label: 'Ketik',
                      icon: MalasIcons.keyboardFill,
                      tone: CategoryTone.bahan,
                      startsAt: 0.4,
                      fromMic: const Offset(
                        -_optionSideReach,
                        _optionHeight + 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MalasSpace.s8),
                option(
                  _MenuOption.tutup,
                  label: 'Tutup',
                  icon: MalasIcons.x,
                  tone: null,
                  startsAt: 0,
                  fromMic: Offset.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A menu button flying out of the mic: it starts at [startsAt] of the open
/// animation, grows from small and overshoots a little into place.
class _FanIn extends StatelessWidget {
  const _FanIn({
    required this.animation,
    required this.startsAt,
    required this.from,
    required this.child,
  });

  final Animation<double> animation;
  final double startsAt;

  /// Where the mic is, measured from the button's own place.
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final progress = Interval(
          startsAt,
          startsAt + 0.6,
        ).transform(animation.value);
        final travelled = Curves.easeOutBack.transform(progress);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: from * (1 - travelled),
            child: Transform.scale(scale: 0.4 + 0.6 * travelled, child: child),
          ),
        );
      },
    );
  }
}

class _CaptureOption extends StatelessWidget {
  const _CaptureOption({
    required this.label,
    required this.icon,
    required this.tone,
    required this.isHovered,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// Null is the white Tutup button.
  final CategoryTone? tone;

  /// The held finger is over it, so letting go picks it.
  final bool isHovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    // The label is part of the target, so tapping "Foto" works too.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isHovered ? 1.15 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.all(MalasSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: MalasSize.navMic,
                child: LipPressable(
                  semanticLabel: label,
                  onPressed: onTap,
                  fill: tone?.base ?? MalasColors.bgOnBrandAction,
                  lip: tone?.lip ?? MalasColors.borderLipSekunder,
                  borderRadius: BorderRadius.circular(MalasSize.navMic / 2),
                  child: SizedBox(
                    height: MalasSize.navMic,
                    child: Icon(
                      icon,
                      size: 28,
                      color: tone == null
                          ? MalasColors.textPrimary
                          : MalasColors.iconOnInk,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MalasSpace.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: MalasColors.bgSurface,
                  borderRadius: BorderRadius.circular(MalasRadius.xs),
                ),
                child: Text(label, style: MalasText.labelTag),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(AppTab tab, {required bool isSelected}) {
  return switch ((tab, isSelected)) {
    (AppTab.beranda, true) => MalasIcons.houseFill,
    (AppTab.beranda, false) => MalasIcons.house,
    (AppTab.catatan, true) => MalasIcons.listBulletsFill,
    (AppTab.catatan, false) => MalasIcons.listBullets,
    (AppTab.analisis, true) => MalasIcons.chartLineFill,
    (AppTab.analisis, false) => MalasIcons.chartLine,
    (AppTab.tanya, true) => MalasIcons.chatCircleTextFill,
    (AppTab.tanya, false) => MalasIcons.chatCircleText,
  };
}
