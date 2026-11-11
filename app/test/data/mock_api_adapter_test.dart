import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_api_adapter.dart';

void main() {
  late ApiClient apiClient;

  setUp(() {
    final adapter = MockApiAdapter(
      basePath: '/api/v1',
      bodiesByRoute: const {
        'GET /home': {'today': 'home'},
        'GET /transactions/:id': {'transaction': 'detail'},
        'POST /transactions': {'transaction': 'saved'},
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://mock/api/v1'))
      ..httpClientAdapter = adapter;
    apiClient = ApiClient(dio);
  });

  test('servesTheBodyForAMatchingRoute', () async {
    expect(await apiClient.get('/home'), {'today': 'home'});
  });

  test('matchesAPathParameterSegment', () async {
    expect(await apiClient.get('/transactions/trx-9'), {
      'transaction': 'detail',
    });
  });

  test('matchesOnMethodAsWellAsPath', () async {
    final body = await apiClient.post('/transactions', body: {});

    expect(body, {'transaction': 'saved'});
  });

  test('answersAnUnknownRouteWithAnApiException', () async {
    await expectLater(
      apiClient.get('/catatan'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'MOCK_MISSING')
            .having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
  });
}
