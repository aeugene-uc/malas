import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../../model/account.dart';
import '../../viewmodel/first_run_view_model.dart';
import '../../viewmodel/session_view_model.dart';
import '../theme/brand_header.dart';
import '../theme/lip.dart';
import '../theme/tokens.dart';

/// The consent wording covers what #17 and the backend contract require:
/// the AI service abroad (§7.1), speech-to-text by Google, and records on
/// our server.
const String consentLine =
    'Foto dan suara dibaca layanan AI di luar Indonesia, suara diubah jadi '
    'teks oleh Google, dan catatan disimpan di server MALAS.';

/// Usability finding 2 (#34): owners in the 9 Nov sessions reached setup not
/// knowing what the app was for, so this one sentence comes before the
/// business name. It is the one explanatory line the UI allows (§5.8).
const String appPurposeLine =
    'Catat uang masuk dan keluar usahamu cukup dengan bicara, foto nota, '
    'atau ketik.';

class FirstRunView extends StatelessWidget {
  const FirstRunView({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FirstRunViewModel(
        account: account,
        authRepository: context.read<AuthRepository>(),
      ),
      child: _FirstRunForm(needsConsent: !account.user.hasConsented),
    );
  }
}

class _FirstRunForm extends StatefulWidget {
  const _FirstRunForm({required this.needsConsent});

  final bool needsConsent;

  @override
  State<_FirstRunForm> createState() => _FirstRunFormState();
}

class _FirstRunFormState extends State<_FirstRunForm> {
  late final _storeNameController = TextEditingController(
    text: context.read<FirstRunViewModel>().initialStoreName,
  );

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FirstRunViewModel>();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const BrandHeader(
            title: 'MALAS',
            height: _formHeaderHeight,
            // Non-empty actions suppresses coins so this form keeps hills only
            // (DESIGN.md §5.4).
            actions: [SizedBox.shrink()],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s12,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(appPurposeLine, style: MalasText.bodyStrong),
                const SizedBox(height: MalasSpace.s20),
                TextField(
                  controller: _storeNameController,
                  textCapitalization: TextCapitalization.words,
                  style: MalasText.body,
                  decoration: const InputDecoration(labelText: 'Nama usaha'),
                ),
                const SizedBox(height: MalasSpace.s24),
                Text('Usaha kamu apa?', style: MalasText.titleSection),
                const SizedBox(height: MalasSpace.s12),
                Wrap(
                  spacing: MalasSpace.s8,
                  runSpacing: MalasSpace.s8,
                  children: [
                    for (final type in BusinessType.values)
                      _BusinessTypeChip(
                        label: type.label,
                        isSelected: viewModel.selectedTypes.contains(type),
                        onPressed: () => viewModel.toggleType(type),
                      ),
                  ],
                ),
                if (widget.needsConsent) ...[
                  const SizedBox(height: MalasSpace.s24),
                  Text(consentLine, style: MalasText.bodySecondary),
                ],
                if (viewModel.errorMessage case final message?) ...[
                  const SizedBox(height: MalasSpace.s16),
                  Text(
                    message,
                    style: MalasText.bodySecondary.copyWith(
                      color: MalasColors.textError,
                    ),
                  ),
                ],
              ],
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
              MalasSpace.s20,
            ),
            child: LipButton(
              label: widget.needsConsent ? 'Setuju dan mulai' : 'Mulai',
              onPressed: viewModel.isSubmitting ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final session = context.read<SessionViewModel>();
    final account = await context.read<FirstRunViewModel>().submit(
      storeName: _storeNameController.text,
    );
    if (account != null) await session.enter(account);
  }
}

class _BusinessTypeChip extends StatelessWidget {
  const _BusinessTypeChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: LipPressable(
        onPressed: onPressed,
        fill: isSelected ? MalasColors.bgBrand : MalasColors.bgSecondary,
        lip: isSelected ? MalasColors.borderLip : MalasColors.borderLipSekunder,
        borderRadius: BorderRadius.circular(MalasRadius.chip),
        child: SizedBox(
          height: MalasSize.buttonKecil,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: MalasText.labelChip.copyWith(
                    color: isSelected
                        ? MalasColors.textOnBrand
                        : MalasColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _formHeaderHeight = 148.0;
