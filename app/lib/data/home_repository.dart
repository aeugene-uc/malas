import '../model/home.dart';
import 'api_client.dart';

class HomeRepository {
  HomeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Home> fetchHome() async {
    final body = await _apiClient.get('/home');
    return Home.fromJson(body as Map<String, Object?>);
  }
}
