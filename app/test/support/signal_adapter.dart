import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';

/// The mock backend, until [isOffline] makes every request fail with no
/// response, the way Dio reports a phone without signal.
class SignalAdapter implements HttpClientAdapter {
  HttpClientAdapter answering = MockApiAdapter(
    bodiesByRoute: mockBodiesByRoute,
  );
  bool isOffline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (isOffline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return answering.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
