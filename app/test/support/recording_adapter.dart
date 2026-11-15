import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:malas/data/mock_api_adapter.dart';

/// Keeps every request so a test can check what was sent.
class RecordingAdapter extends MockApiAdapter {
  RecordingAdapter({required super.bodiesByRoute});

  final List<RequestOptions> requests = [];

  RequestOptions get lastRequest => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return super.fetch(options, requestStream, cancelFuture);
  }
}
