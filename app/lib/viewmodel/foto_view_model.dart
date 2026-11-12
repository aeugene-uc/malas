import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/draft_repository.dart';
import '../data/api_client.dart';
import '../model/draft.dart';

/// Foto (§7.2): a receipt, a supplier nota, a sales note or a notebook page.
class FotoViewModel extends ChangeNotifier {
  FotoViewModel({required this._imagePicker, required this._draftRepository});

  /// Wide enough for small receipt print, small enough to send on a weak
  /// mobile connection.
  static const double maxImageWidth = 1600;
  static const int jpegQuality = 70;

  final ImagePicker _imagePicker;
  final DraftRepository _draftRepository;

  PhotoKind _kind = PhotoKind.nota;
  Uint8List? _imageBytes;
  bool _isReading = false;
  String? _errorMessage;

  PhotoKind get kind => _kind;
  Uint8List? get imageBytes => _imageBytes;
  bool get hasImage => _imageBytes != null;
  bool get isReading => _isReading;
  String? get errorMessage => _errorMessage;

  void selectKind(PhotoKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    notifyListeners();
  }

  /// Leaves the current photo in place when the owner backs out of the
  /// camera or gallery.
  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: maxImageWidth,
      imageQuality: jpegQuality,
    );
    if (pickedFile == null) return;
    _imageBytes = await pickedFile.readAsBytes();
    _errorMessage = null;
    notifyListeners();
  }

  /// Returns null when the read failed. The photo stays, so the owner can try
  /// again once there is signal.
  Future<AiReadResult?> read() async {
    final imageBytes = _imageBytes;
    if (imageBytes == null) return null;
    _isReading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _draftRepository.readPhoto(
        kind: _kind,
        imageBytes: imageBytes,
      );
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isReading = false;
      notifyListeners();
    }
  }
}
