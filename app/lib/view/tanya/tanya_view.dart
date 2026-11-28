import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/tanya_repository.dart';
import '../../viewmodel/session_view_model.dart';
import '../../viewmodel/tanya_view_model.dart';
import '../first_run/trial_sheet.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/tokens.dart';
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandHeader(title: 'Tanya', height: _tanyaHeaderHeight),
          Expanded(
            child: ListView(
              reverse: true,
              padding: EdgeInsets.fromLTRB(
                sidePaddingFor(MediaQuery.sizeOf(context).width),
                MalasSpace.s8,
                sidePaddingFor(MediaQuery.sizeOf(context).width),
                MalasSpace.s16,
              ),
              children: [
                for (final exchange in viewModel.exchanges.reversed)
                  _ExchangeCards(exchange: exchange),
              ],
            ),
          ),
          _QuestionComposer(
            controller: _questionController,
            isAsking: viewModel.isAsking,
            onSend: _send,
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

class _QuestionComposer extends StatelessWidget {
  const _QuestionComposer({
    required this.controller,
    required this.isAsking,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isAsking;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            sidePaddingFor(MediaQuery.sizeOf(context).width),
            MalasSpace.s12,
            sidePaddingFor(MediaQuery.sizeOf(context).width),
            MalasSpace.s12 + MalasSize.navBumpRise,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  style: MalasText.body,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(labelText: 'Tanya'),
                ),
              ),
              const SizedBox(width: MalasSpace.s8),
              SizedBox(
                width: MalasSize.touch,
                child: Tooltip(
                  message: 'Kirim',
                  excludeFromSemantics: true,
                  child: LipPressable(
                    semanticLabel: 'Kirim',
                    onPressed: isAsking ? null : onSend,
                    fill: MalasColors.bgBrand,
                    lip: MalasColors.borderLip,
                    borderRadius: BorderRadius.circular(MalasSize.touch / 2),
                    child: const SizedBox(
                      height: MalasSize.touch,
                      child: Icon(
                        MalasIcons.paperPlaneRight,
                        size: _sendIconSize,
                        color: MalasColors.iconOnInk,
                      ),
                    ),
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

class _ExchangeCards extends StatelessWidget {
  const _ExchangeCards({required this.exchange});

  final TanyaExchange exchange;

  @override
  Widget build(BuildContext context) {
    final answer = exchange.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: MalasSpace.s8),
            padding: const EdgeInsets.all(MalasSpace.s12),
            constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
            decoration: BoxDecoration(
              color: MalasColors.bgSelected,
              borderRadius: BorderRadius.circular(MalasRadius.lg),
            ),
            child: Text(exchange.question, style: MalasText.body),
          ),
        ),
        if (exchange.isPending)
          const _AnswerCard(child: _AnswerSkeleton())
        else if (exchange.errorMessage case final message?)
          _AnswerCard(
            child: Text(
              message,
              style: MalasText.body.copyWith(color: MalasColors.textError),
            ),
          )
        else if (answer != null)
          _AnswerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fillAnswer(answer), style: MalasText.body),
                if (answer.daysRecorded case final days?)
                  Padding(
                    padding: const EdgeInsets.only(top: MalasSpace.s8),
                    child: Text(
                      '$days hari dicatat',
                      style: MalasText.bodySecondary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// DESIGN.md §2: answers are information, so flat cards with 2px borderCard.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
        child: Padding(
          padding: const EdgeInsets.only(bottom: MalasSpace.s16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(MalasSpace.s16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerSkeleton extends StatelessWidget {
  const _AnswerSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _skeletonLineWide,
            height: MalasSpace.s16,
            decoration: BoxDecoration(
              color: MalasColors.bgSkeleton,
              borderRadius: BorderRadius.circular(MalasRadius.xs),
            ),
          ),
          const SizedBox(height: MalasSpace.s8),
          Container(
            width: _skeletonLineShort,
            height: MalasSpace.s16,
            decoration: BoxDecoration(
              color: MalasColors.bgSkeleton,
              borderRadius: BorderRadius.circular(MalasRadius.xs),
            ),
          ),
        ],
      ),
    );
  }
}

const _tanyaHeaderHeight = 160.0;
const _sendIconSize = 20.0;
const _maxBubbleWidth = 300.0;
const _skeletonLineWide = 200.0;
const _skeletonLineShort = 120.0;
