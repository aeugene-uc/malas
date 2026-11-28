import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/session_view_model.dart';
import '../app_shell.dart';
import '../theme/lip.dart';
import '../theme/tokens.dart';
import 'first_run_view.dart';
import 'sign_in_view.dart';
import 'trial_sheet.dart';

/// The app's first screen: sign-in, first-run setup, or the four tabs.
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    return switch (session.stage) {
      SessionStage.loading => const Scaffold(
        backgroundColor: MalasColors.bgBrand,
        body: Center(child: _LoadingTitle()),
      ),
      SessionStage.failed => _StartFailed(
        message: session.errorMessage ?? '',
        onRetry: session.start,
      ),
      SessionStage.signedOut => const SignInView(),
      SessionStage.firstRun => FirstRunView(account: session.account!),
      SessionStage.ready => _ReadyShell(
        isTrialSheetDue: session.isTrialSheetDue,
      ),
    };
  }
}

class _LoadingTitle extends StatelessWidget {
  const _LoadingTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'MALAS',
      style: MalasText.titleScreen.copyWith(color: MalasColors.textOnBrand),
    );
  }
}

/// The four tabs, plus the trial sheet once when it is due.
class _ReadyShell extends StatefulWidget {
  const _ReadyShell({required this.isTrialSheetDue});

  final bool isTrialSheetDue;

  @override
  State<_ReadyShell> createState() => _ReadyShellState();
}

class _ReadyShellState extends State<_ReadyShell> {
  @override
  void initState() {
    super.initState();
    if (widget.isTrialSheetDue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askForPlan());
    }
  }

  @override
  Widget build(BuildContext context) => const AppShell();

  Future<void> _askForPlan() async {
    final session = context.read<SessionViewModel>();
    final chosenPlan = await showTrialSheet(context);
    await session.answerTrialSheet(chosenPlan);
  }
}

class _StartFailed extends StatelessWidget {
  const _StartFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(MalasSpace.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message, style: MalasText.body, textAlign: TextAlign.center),
              const SizedBox(height: MalasSpace.s16),
              LipButton(label: 'Coba lagi', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
