import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../../model/account.dart';
import '../../viewmodel/first_run_view_model.dart';
import '../../viewmodel/session_view_model.dart';

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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(appPurposeLine, style: textTheme.titleMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _storeNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama usaha'),
            ),
            const SizedBox(height: 24),
            Text('Usaha kamu apa?', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in BusinessType.values)
                  FilterChip(
                    label: Text(type.label),
                    selected: viewModel.selectedTypes.contains(type),
                    onSelected: (_) => viewModel.toggleType(type),
                  ),
              ],
            ),
            if (widget.needsConsent) ...[
              const SizedBox(height: 24),
              Text(consentLine, style: textTheme.bodySmall),
            ],
            if (viewModel.errorMessage case final message?) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: viewModel.isSubmitting ? null : _submit,
              child: Text(widget.needsConsent ? 'Setuju dan mulai' : 'Mulai'),
            ),
          ],
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
