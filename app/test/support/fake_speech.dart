import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
