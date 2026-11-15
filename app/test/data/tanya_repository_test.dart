import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/tanya_repository.dart';

import '../support/recording_adapter.dart';

void main() {
  test('sendsTheQuestionToAiAsk', () async {
    final adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    final repository = TanyaRepository(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
      ),
    );

    final answer = await repository.ask('Apa yang paling laku minggu ini?');

    expect(adapter.lastRequest.path, '/ai/ask');
    expect(adapter.lastRequest.data, {
      'question': 'Apa yang paling laku minggu ini?',
    });
    expect(answer.figures, hasLength(4));
  });
}
