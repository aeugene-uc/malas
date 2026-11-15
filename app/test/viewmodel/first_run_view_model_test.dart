import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/account.dart';
import 'package:malas/viewmodel/first_run_view_model.dart';
import 'package:malas/viewmodel/sign_in_view_model.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;
  late List<String> requestRoutes;
  late AuthRepository authRepository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    requestRoutes = [];
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestRoutes.add('${options.method} ${options.path}');
            handler.next(options);
          },
        ),
      );
    authRepository = AuthRepository(
      apiClient: ApiClient(dio),
      secureStorage: const FlutterSecureStorage(),
    );
  });

  Account newAccount() => Account.fromJson(
    mockBodiesByRoute['POST /auth/register']! as Map<String, Object?>,
  );

  test('givesConsentBeforeSavingTheStoreBecauseWritesNeedIt', () async {
    final viewModel = FirstRunViewModel(
      account: newAccount(),
      authRepository: authRepository,
    );

    viewModel.toggleType(BusinessType.makananMinuman);
    final account = await viewModel.submit(storeName: 'Warung Pak Budi');

    expect(requestRoutes, [
      'POST /auth/consent',
      'PATCH /stores/store-2',
      'GET /auth/me',
    ]);
    expect(account!.isSetUp, isTrue);
  });

  test('needsANameAndAtLeastOneJenisUsaha', () async {
    final viewModel = FirstRunViewModel(
      account: newAccount(),
      authRepository: authRepository,
    );

    final account = await viewModel.submit(storeName: 'Warung Pak Budi');

    expect(account, isNull);
    expect(viewModel.errorMessage, 'Isi nama usaha dan pilih jenis usaha');
    expect(requestRoutes, isEmpty);
  });

  test('tappingAJenisUsahaTwiceUnselectsIt', () {
    final viewModel = FirstRunViewModel(
      account: newAccount(),
      authRepository: authRepository,
    );

    viewModel.toggleType(BusinessType.jasa);
    viewModel.toggleType(BusinessType.jasa);

    expect(viewModel.selectedTypes, isEmpty);
  });

  test('daftarNeedsTheOwnersName', () async {
    final viewModel = SignInViewModel(authRepository: authRepository)
      ..selectMode(SignInMode.daftar);

    final account = await viewModel.submit(
      name: ' ',
      phone: '0812',
      password: 'rahasia',
    );

    expect(account, isNull);
    expect(viewModel.errorMessage, 'Lengkapi semua kolom');
    expect(requestRoutes, isEmpty);
  });

  test('masukSendsThePhoneAsTyped', () async {
    final viewModel = SignInViewModel(authRepository: authRepository);

    final account = await viewModel.submit(
      name: '',
      phone: ' 0812 3456 7890 ',
      password: 'rahasia',
    );

    expect(requestRoutes, ['POST /auth/login']);
    expect(adapter.lastRequest.data, {
      'phone': '0812 3456 7890',
      'password': 'rahasia',
    });
    expect(account, isNotNull);
  });
}
