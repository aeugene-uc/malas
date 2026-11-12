import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/draft_repository.dart';
import '../data/api_client.dart';
import '../model/draft.dart';

/// Bicara (§7.2): tap to start, tap to stop, "Tambah" adds another part.
/// Android ends a recognition at a short pause, so a long note is several
/// parts, joined with a newline when it is read.
class BicaraViewModel extends ChangeNotifier {
  BicaraViewModel({required this._speech, required this._draftRepository});

  final SpeechToText _speech;
  final DraftRepository _draftRepository;

  final List<String> _finishedParts = [];
  String _currentPart = '';
  bool _isListening = false;
  bool _isReading = false;
  String? _errorMessage;

  /// Every part said so far, including the one still being recognised.
  List<String> get transcriptParts => [
    ..._finishedParts,
    if (_currentPart.trim().isNotEmpty) _currentPart.trim(),
  ];

  bool get hasTranscript => transcriptParts.isNotEmpty;
  bool get isListening => _isListening;
  bool get isReading => _isReading;
  String? get errorMessage => _errorMessage;

  Future<void> startListening() async {
    _errorMessage = null;
    final isAvailable = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (!isAvailable) {
      _errorMessage = 'Mikrofon tidak tersedia';
      notifyListeners();
      return;
    }
    _isListening = true;
    notifyListeners();
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: 'id_ID',
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// The recogniser still delivers the final words of this part after it
  /// stops, so the part is finished by [_onResult] or [_onStatus], not here.
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  /// Returns null when the read failed. The transcript stays, so the owner
  /// can try again once there is signal.
  Future<AiReadResult?> read() async {
    _isReading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final transcript = transcriptParts.join('\n');
      return await _draftRepository.readTranscript(transcript);
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isReading = false;
      notifyListeners();
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _currentPart = result.recognizedWords;
    if (result.finalResult) {
      _finishCurrentPart();
    } else {
      notifyListeners();
    }
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) _finishCurrentPart();
  }

  void _onError(SpeechRecognitionError error) {
    _errorMessage = 'Suara tidak terbaca';
    _finishCurrentPart();
  }

  void _finishCurrentPart() {
    final finishedPart = _currentPart.trim();
    if (finishedPart.isNotEmpty) _finishedParts.add(finishedPart);
    _currentPart = '';
    _isListening = false;
    notifyListeners();
  }
}
