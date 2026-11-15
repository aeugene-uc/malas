import '../model/tanya_answer.dart';
import 'api_client.dart';

/// Tanya (§7.8, Pro). The server picks one of five query functions, runs it
/// in code and returns the figures with the model's wording.
class TanyaRepository {
  TanyaRepository(this._apiClient);

  final ApiClient _apiClient;

  /// A free plan gets [ApiException] code `PLAN_REQUIRED` (403), and the
  /// monthly limit gets status 429.
  Future<TanyaAnswer> ask(String question) async {
    final body = await _apiClient.post('/ai/ask', body: {'question': question});
    return TanyaAnswer.fromJson(body as Map<String, Object?>);
  }
}
