import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/viewmodel/bicara_view_model.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

  test('finishesThePartWhenTheRecogniserStopsAtAPause', () async {
    final viewModel = buildViewModel();

    await viewModel.startListening();
    speech.hear('jual kopi 3', isFinal: false);
    speech.reportStatus(SpeechToText.doneStatus);

    expect(viewModel.transcriptParts, ['jual kopi 3']);
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

/// Stands in for the platform recogniser. A test says what was heard.
class FakeSpeech extends Fake implements SpeechToText {
  bool isMicrophoneAvailable = true;
  SpeechStatusListener? _onStatus;
  SpeechResultListener? _onResult;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    _onStatus = onStatus;
    return isMicrophoneAvailable;
  }

  @override
  Future<dynamic> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {}

  void hear(String words, {required bool isFinal}) {
    final resultType = isFinal ? ResultType.finalResult : ResultType.partial;
    _onResult!(
      SpeechRecognitionResult([
        SpeechRecognitionWords(words, null, 1),
      ], resultType.value),
    );
  }

  void reportStatus(String status) => _onStatus!(status);
}
