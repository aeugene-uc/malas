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
              Expanded(
                child: _NavMic(
                  onTap: () => viewModel.requestCapture(CaptureMode.bicara),
                  onHold: () => _showCaptureMenu(context, viewModel),
                ),
              ),
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

/// §4.1: tap records straight away, hold opens Bicara, Foto and Ketik.
class _NavMic extends StatelessWidget {
  const _NavMic({required this.onTap, required this.onHold});

  final VoidCallback onTap;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    // Taller than the bar: it rises above the other tabs (§3).
    return Stack(
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
                  child: LipPressable(
                    semanticLabel: 'Bicara',
                    onPressed: onTap,
                    onLongPress: onHold,
                    fill: MalasColors.bgBrand,
                    lip: MalasColors.borderLip,
                    borderRadius: BorderRadius.circular(MalasSize.navMic / 2),
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
              Text('Bicara', style: MalasText.labelNav),
            ],
          ),
        ),
      ],
    );
  }
}

/// §4.1 A3: three round buttons fan out above the mic over the scrim, and
/// the mic becomes Tutup.
Future<void> _showCaptureMenu(
  BuildContext context,
  AppShellViewModel viewModel,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: MalasColors.scrim,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: Tween<double>(
        begin: 0.6,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
      alignment: Alignment.bottomCenter,
      child: child,
    ),
    pageBuilder: (dialogContext, _, _) {
      void pick(CaptureMode mode) {
        Navigator.of(dialogContext).pop();
        viewModel.requestCapture(mode);
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
                  _CaptureOption(
                    label: 'Bicara',
                    icon: MalasIcons.microphoneFill,
                    onTap: () => pick(CaptureMode.bicara),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CaptureOption(
                        label: 'Foto',
                        icon: MalasIcons.cameraFill,
                        tone: CategoryTone.minuman,
                        onTap: () => pick(CaptureMode.foto),
                      ),
                      const SizedBox(width: 96),
                      _CaptureOption(
                        label: 'Ketik',
                        icon: MalasIcons.keyboardFill,
                        tone: CategoryTone.bahan,
                        onTap: () => pick(CaptureMode.ketik),
                      ),
                    ],
                  ),
                  const SizedBox(height: MalasSpace.s8),
                  _CaptureOption(
                    label: 'Tutup',
                    icon: MalasIcons.x,
                    tone: null,
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CaptureOption extends StatelessWidget {
  const _CaptureOption({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone = CategoryTone.penjualan,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Null is the white Tutup button.
  final CategoryTone? tone;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    // The label is part of the target, so tapping "Foto" works too.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
