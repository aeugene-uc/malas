import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers every request with [statusCode] and a backend error body.
class StatusAdapter implements HttpClientAdapter {
  StatusAdapter(
    this.statusCode, {
    this.code = 'FAILED',
    this.message = 'Server sedang bermasalah',
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'code': code, 'message': message},
      }),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
