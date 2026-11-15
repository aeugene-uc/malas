import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/view/bicara/bicara_view.dart';
import 'package:malas/view/foto/foto_view.dart';
import 'package:malas/viewmodel/bicara_view_model.dart';
import 'package:malas/viewmodel/foto_view_model.dart';
import 'package:provider/provider.dart';

import '../support/fake_speech.dart';
import '../viewmodel/foto_view_model_test.dart' show FakeImagePicker;

/// The smallest valid PNG, so Image.memory can decode the picked photo.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  late DraftRepository draftRepository;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = MockApiAdapter(bodiesByRoute: mockBodiesByRoute);
    draftRepository = DraftRepository(ApiClient(dio));
  });

  testWidgets('bicaraBacaClosesTheScreenWithTheReadResult', (tester) async {
    final speech = FakeSpeech();
    final viewModel = BicaraViewModel(
      speech: speech,
      draftRepository: draftRepository,
    );
    await viewModel.startListening();
    speech.hear('jual nasi goreng 12', isFinal: true);

    final popped = await _openReadAndWait(
      tester,
      ChangeNotifierProvider.value(value: viewModel, child: const BicaraView()),
    );

    expect(popped, isNotNull);
    expect(find.byType(BicaraView), findsNothing);
  });

  testWidgets('fotoBacaClosesTheScreenWithTheReadResult', (tester) async {
    final imagePicker = FakeImagePicker()..nextImageBytes = onePixelPng;
    final viewModel = FotoViewModel(
      imagePicker: imagePicker,
      draftRepository: draftRepository,
    );
    await viewModel.pickImage(ImageSource.camera);

    final popped = await _openReadAndWait(
      tester,
      ChangeNotifierProvider.value(value: viewModel, child: const FotoView()),
    );

    expect(popped, isNotNull);
    expect(find.byType(FotoView), findsNothing);
  });
}

/// Pushes [screen], taps Baca, lets the mock reply arrive, and returns what
/// the screen popped with.
Future<AiReadResult?> _openReadAndWait(
  WidgetTester tester,
  Widget screen,
) async {
  AiReadResult? popped;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            popped = await Navigator.of(context)
                .push<AiReadResult>(MaterialPageRoute(builder: (_) => screen));
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Baca'));
  // On a phone the screen redraws as "Membaca…" before the reply arrives.
  await tester.pump();
  // The mock adapter answers on real async, which the test clock does not run.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
  return popped;
}
