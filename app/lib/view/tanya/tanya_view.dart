import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/tanya_repository.dart';
import '../../viewmodel/session_view_model.dart';
import '../../viewmodel/tanya_view_model.dart';
import '../first_run/trial_sheet.dart';
import 'tanya_text.dart';

/// Tanya (§7.8): ask in words, get an answer whose numbers come from code.
class TanyaView extends StatelessWidget {
  const TanyaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TanyaViewModel(
        tanyaRepository: TanyaRepository(context.read<ApiClient>()),
      ),
      child: const _TanyaScreen(),
    );
  }
}

class _TanyaScreen extends StatefulWidget {
  const _TanyaScreen();

  @override
  State<_TanyaScreen> createState() => _TanyaScreenState();
}

class _TanyaScreenState extends State<_TanyaScreen> {
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TanyaViewModel>();
    if (viewModel.isPlanSheetDue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerPro());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tanya')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.all(16),
              children: [
                for (final exchange in viewModel.exchanges.reversed)
                  _ExchangeBubbles(exchange: exchange),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(labelText: 'Tanya'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kirim',
                    icon: const Icon(Icons.send),
                    onPressed: viewModel.isAsking ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final question = _questionController.text;
    if (question.trim().isEmpty) return;
    _questionController.clear();
    context.read<TanyaViewModel>().ask(question);
  }

  Future<void> _offerPro() async {
    final viewModel = context.read<TanyaViewModel>();
    if (!viewModel.isPlanSheetDue) return;
    viewModel.planSheetShown();
    final session = context.read<SessionViewModel?>();
    final chosenPlan = await showTrialSheet(
      context,
      title: 'Tanya ada di paket Pro',
    );
    await session?.choosePlan(chosenPlan);
  }
}

class _ExchangeBubbles extends StatelessWidget {
  const _ExchangeBubbles({required this.exchange});

  final TanyaExchange exchange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final answer = exchange.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bubble(
          alignment: Alignment.centerRight,
          color: colorScheme.primaryContainer,
          child: Text(exchange.question),
        ),
        if (exchange.isPending)
          const _Bubble(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (exchange.errorMessage case final message?)
          _Bubble(
            alignment: Alignment.centerLeft,
            child: Text(message, style: TextStyle(color: colorScheme.error)),
          )
        else if (answer != null)
          _Bubble(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fillAnswer(answer)),
                if (answer.daysRecorded case final days?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$days hari dicatat',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.alignment, required this.child, this.color});

  final Alignment alignment;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}
