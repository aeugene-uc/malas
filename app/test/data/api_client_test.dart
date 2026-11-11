import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';

void main() {
  late _RecordingAdapter adapter;
  late ApiClient apiClient;

  setUp(() {
    adapter = _RecordingAdapter();
    apiClient = ApiClient(Dio()..httpClientAdapter = adapter);
  });

  test('returnsDecodedJsonOnSuccess', () async {
    adapter.reply(200, {'masuk': 420000});

    final body = await apiClient.get('/home');

    expect(body, {'masuk': 420000});
  });

  test('sendsBearerTokenAndIdempotencyKey', () async {
    adapter.reply(201, {'transaction': <String, Object?>{}});
    apiClient.token = 'abc';

    await apiClient.post('/transactions', body: {}, idempotencyKey: 'key-1');

    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer abc');
    expect(adapter.lastRequest!.headers['Idempotency-Key'], 'key-1');
  });

  test('turnsBackendErrorBodyIntoApiException', () async {
    adapter.reply(400, {
      'error': {
        'code': 'VALIDATION_FAILED',
        'message': 'Total wajib diisi',
        'fields': {'total': 'wajib'},
      },
    });

    final error = await _catchApiException(() => apiClient.get('/home'));

    expect(error.code, 'VALIDATION_FAILED');
    expect(error.message, 'Total wajib diisi');
    expect(error.statusCode, 400);
    expect(error.messageByField, {'total': 'wajib'});
    expect(error.isNetworkError, isFalse);
  });

  test('marksAnErrorWithoutABackendBodyByItsStatus', () async {
    adapter.reply(502, 'Bad Gateway');

    final error = await _catchApiException(() => apiClient.get('/home'));

    expect(error.code, 'HTTP_502');
    expect(error.statusCode, 502);
  });
}

Future<ApiException> _catchApiException(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (error) {
    return error;
  }
  fail('expected an ApiException');
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  int _statusCode = 200;
  Object? _body;

  void reply(int statusCode, Object? body) {
    _statusCode = statusCode;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final isJson = _body is Map;
    return ResponseBody.fromString(
      isJson ? jsonEncode(_body) : '$_body',
      _statusCode,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? Headers.jsonContentType : Headers.textPlainContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
