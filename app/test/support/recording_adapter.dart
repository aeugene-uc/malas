import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:malas/data/mock_api_adapter.dart';

/// Keeps the last request so a test can check what was sent.
class RecordingAdapter extends MockApiAdapter {
  RecordingAdapter({required super.bodiesByRoute});

  late RequestOptions lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return super.fetch(options, requestStream, cancelFuture);
  }
}
