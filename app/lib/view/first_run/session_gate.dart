import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/session_view_model.dart';
import '../app_shell.dart';
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
        body: Center(child: CircularProgressIndicator()),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
