import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/viewmodel/bicara_view_model.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../support/fake_speech.dart';
import '../support/recording_adapter.dart';

void main() {
  late FakeSpeech speech;
  late RecordingAdapter adapter;

  BicaraViewModel buildViewModel({Map<String, Object>? bodiesByRoute}) {
    adapter = RecordingAdapter(
      bodiesByRoute: bodiesByRoute ?? mockBodiesByRoute,
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter;
    return BicaraViewModel(
      speech: speech,
      draftRepository: DraftRepository(ApiClient(dio)),
    );
  }

  setUp(() => speech = FakeSpeech());

  test('joinsEveryPartWithANewlineWhenRead', () async {
    final viewModel = buildViewModel();

    await viewModel.startListening();
    speech.hear('jual nasi goreng 12', isFinal: true);
    await viewModel.startListening();
    speech.hear('beli gas', isFinal: false);
    speech.hear('beli gas 25 ribu', isFinal: true);
    final readResult = await viewModel.read();

    expect(adapter.lastRequest.data, {
      'kind': 'VOICE',
      'transcript': 'jual nasi goreng 12\nbeli gas 25 ribu',
    });
    expect(readResult!.drafts, hasLength(3));
  });

  test('keepsTheFinalWordsThatArriveAfterStopOnce', () async {
    final viewModel = buildViewModel();

    await viewModel.startListening();
    speech.hear('es teh', isFinal: false);
    await viewModel.stopListening();
    speech.hear('es teh selawe', isFinal: true);
    speech.reportStatus(SpeechToText.doneStatus);

    expect(viewModel.transcriptParts, ['es teh selawe']);
    expect(viewModel.isListening, isFalse);
  });

  test('keepsListeningAfterAPauseUntilBerhenti', () async {
    final viewModel = buildViewModel();

    await viewModel.startListening();
    speech.hear('jual kopi 3', isFinal: false);
    speech.reportError('error_speech_timeout');
    speech.reportStatus(SpeechToText.doneStatus);
    speech.hear('beli gula', isFinal: true);
    await viewModel.stopListening();
    speech.reportStatus(SpeechToText.doneStatus);

    expect(viewModel.transcriptParts, ['jual kopi 3', 'beli gula']);
    expect(speech.listenCount, 2);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isListening, isFalse);
  });

  test('stopsWithAMessageWhenTheRecogniserFails', () async {
    final viewModel = buildViewModel();

    await viewModel.startListening();
    speech.hear('jual kopi 3', isFinal: false);
    speech.reportError('error_network');
    speech.reportStatus(SpeechToText.doneStatus);

    expect(viewModel.transcriptParts, ['jual kopi 3']);
    expect(speech.listenCount, 1);
    expect(viewModel.errorMessage, 'Suara tidak terbaca');
    expect(viewModel.isListening, isFalse);
  });

  test('keepsTheTranscriptAndShowsTheMessageWhenTheReadFails', () async {
    final viewModel = buildViewModel(bodiesByRoute: const {});

    await viewModel.startListening();
    speech.hear('jual kopi 3', isFinal: true);
    final readResult = await viewModel.read();

    expect(readResult, isNull);
    expect(viewModel.errorMessage, contains('/ai/read'));
    expect(viewModel.transcriptParts, ['jual kopi 3']);
    expect(viewModel.isReading, isFalse);
  });

  test('showsAMessageWhenTheMicrophoneIsUnavailable', () async {
    speech.isMicrophoneAvailable = false;
    final viewModel = buildViewModel();

    await viewModel.startListening();

    expect(viewModel.errorMessage, 'Mikrofon tidak tersedia');
    expect(viewModel.isListening, isFalse);
  });
}
