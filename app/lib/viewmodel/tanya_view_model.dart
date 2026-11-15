import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/tanya_repository.dart';
import '../model/tanya_answer.dart';

/// One question and what came back: an answer, an error, or nothing yet.
class TanyaExchange {
  const TanyaExchange({required this.question, this.answer, this.errorMessage});

  final String question;
  final TanyaAnswer? answer;
  final String? errorMessage;

  bool get isPending => answer == null && errorMessage == null;
}

/// Tanya (§7.8): a chat of questions and answers for this visit. A free
/// plan is offered Pro instead of an answer.
class TanyaViewModel extends ChangeNotifier {
  TanyaViewModel({required this._tanyaRepository});

  static const String planRequiredCode = 'PLAN_REQUIRED';

  final TanyaRepository _tanyaRepository;

  List<TanyaExchange> _exchanges = const [];
  bool _isPlanSheetDue = false;

  List<TanyaExchange> get exchanges => _exchanges;
  bool get isAsking => _exchanges.isNotEmpty && _exchanges.last.isPending;

  /// Set when the server says Tanya needs Pro, so the view shows the plans.
  bool get isPlanSheetDue => _isPlanSheetDue;

  Future<void> ask(String question) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty || isAsking) return;
    _exchanges = [..._exchanges, TanyaExchange(question: trimmedQuestion)];
    notifyListeners();
    try {
      final answer = await _tanyaRepository.ask(trimmedQuestion);
      _finishLast(TanyaExchange(question: trimmedQuestion, answer: answer));
    } on ApiException catch (error) {
      _isPlanSheetDue = error.code == planRequiredCode;
      _finishLast(
        TanyaExchange(question: trimmedQuestion, errorMessage: error.message),
      );
    }
  }

  void planSheetShown() {
    _isPlanSheetDue = false;
    notifyListeners();
  }

  void _finishLast(TanyaExchange exchange) {
    _exchanges = [..._exchanges.sublist(0, _exchanges.length - 1), exchange];
    notifyListeners();
  }
}
