import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:malas/data/draft_repository.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/draft.dart';
import 'package:malas/viewmodel/foto_view_model.dart';

import '../support/recording_adapter.dart';

void main() {
  late FakeImagePicker imagePicker;
  late RecordingAdapter adapter;

  FotoViewModel buildViewModel({Map<String, Object>? bodiesByRoute}) {
    adapter = RecordingAdapter(
      bodiesByRoute: bodiesByRoute ?? mockBodiesByRoute,
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter;
    return FotoViewModel(
      imagePicker: imagePicker,
      draftRepository: DraftRepository(ApiClient(dio)),
    );
  }

  setUp(() => imagePicker = FakeImagePicker());

  test('readsTheCompressedPhotoAsTheChosenKind', () async {
    final viewModel = buildViewModel();
    imagePicker.nextImageBytes = Uint8List.fromList(utf8.encode('halaman'));

    viewModel.selectKind(PhotoKind.bukuCatatan);
    await viewModel.pickImage(ImageSource.camera);
    final readResult = await viewModel.read();

    final form = adapter.lastRequest.data as FormData;
    expect(Map.fromEntries(form.fields)['kind'], 'NOTEBOOK');
    expect(imagePicker.lastMaxWidth, FotoViewModel.maxImageWidth);
    expect(imagePicker.lastImageQuality, FotoViewModel.jpegQuality);
    expect(readResult!.drafts, isNotEmpty);
  });

  test('keepsThePhotoWhenTheOwnerBacksOutOfThePicker', () async {
    final viewModel = buildViewModel();
    imagePicker.nextImageBytes = Uint8List.fromList(utf8.encode('nota'));
    await viewModel.pickImage(ImageSource.gallery);

    imagePicker.nextImageBytes = null;
    await viewModel.pickImage(ImageSource.gallery);

    expect(viewModel.imageBytes, utf8.encode('nota'));
  });

  test('keepsThePhotoAndShowsTheMessageWhenTheReadFails', () async {
    final viewModel = buildViewModel(bodiesByRoute: const {});
    imagePicker.nextImageBytes = Uint8List.fromList(utf8.encode('nota'));
    await viewModel.pickImage(ImageSource.camera);

    final readResult = await viewModel.read();

    expect(readResult, isNull);
    expect(viewModel.errorMessage, contains('/ai/read'));
    expect(viewModel.hasImage, isTrue);
    expect(viewModel.isReading, isFalse);
  });
}

/// Returns [nextImageBytes] as the picked photo, or nothing when it is null.
class FakeImagePicker extends Fake implements ImagePicker {
  Uint8List? nextImageBytes;
  double? lastMaxWidth;
  int? lastImageQuality;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastMaxWidth = maxWidth;
    lastImageQuality = imageQuality;
    final imageBytes = nextImageBytes;
    return imageBytes == null ? null : XFile.fromData(imageBytes);
  }
}
