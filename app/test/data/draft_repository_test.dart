import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/draft.dart';

import '../support/recording_adapter.dart';

void main() {
  test('readTranscriptReturnsTheDrafts', () async {
    final repository = DraftRepository(_mockApiClient());

    final result = await repository.readTranscript('jual nasi goreng 12');

    expect(result.drafts, hasLength(3));
  });

  test('readPhotoSendsTheKindAndTheSha256OfTheImage', () async {
    final adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter;
    final imageBytes = Uint8List.fromList(utf8.encode('nota'));

    final result = await DraftRepository(ApiClient(dio))
        .readPhoto(kind: PhotoKind.bukuCatatan, imageBytes: imageBytes);

    final form = adapter.lastRequest.data as FormData;
    final fieldsByName = Map.fromEntries(form.fields);
    expect(fieldsByName['kind'], 'NOTEBOOK');
    expect(fieldsByName['imageHash'], sha256.convert(imageBytes).toString());
    expect(form.files.single.key, 'image');
    expect(result.drafts, hasLength(3));
  });

  test('saveSendsTheDraftWithItsIdempotencyKey', () async {
    final adapter = _CapturingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter;
    final repository = DraftRepository(ApiClient(dio));
    final draft = (await DraftRepository(_mockApiClient()).readTranscript('x'))
        .drafts
        .first;

    final result = await repository.save(draft, idempotencyKey: 'key-1');

    expect(adapter.lastRequest!.headers['Idempotency-Key'], 'key-1');
    expect(adapter.lastRequest!.data, draft.toJson());
    expect(result.transaction.id, 'trx-new');
  });

  test('generatesAVersion4KeyThatDiffersEachTime', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final first = generateIdempotencyKey();
    final second = generateIdempotencyKey();

    expect(first, matches(pattern));
    expect(second, matches(pattern));
    expect(first, isNot(second));
  });
}

ApiClient _mockApiClient() {
  final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
    ..httpClientAdapter = MockApiAdapter(bodiesByRoute: mockBodiesByRoute);
  return ApiClient(dio);
}

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(mockBodiesByRoute['POST /transactions']),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
