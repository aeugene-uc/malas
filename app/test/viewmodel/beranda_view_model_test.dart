import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/home_repository.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/viewmodel/beranda_view_model.dart';

void main() {
  test('loadsHomeFromTheRepository', () async {
    final viewModel = _buildViewModel(mockBodiesByRoute);

    await viewModel.load();

    expect(viewModel.home!.today.masuk, 420000);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('showsTheServerMessageWhenLoadFails', () async {
    final viewModel = _buildViewModel(const {});

    await viewModel.load();

    expect(viewModel.home, isNull);
    expect(viewModel.errorMessage, 'Mock belum ada: GET /home');
    expect(viewModel.isLoading, isFalse);
  });

  test('keepsTheLastHomeWhenARefreshFails', () async {
    final bodiesByRoute = Map<String, Object>.of(mockBodiesByRoute);
    final viewModel = _buildViewModel(bodiesByRoute);
    await viewModel.load();

    bodiesByRoute.remove('GET /home');
    await viewModel.load();

    expect(viewModel.home!.today.masuk, 420000);
    expect(viewModel.errorMessage, isNotNull);
  });
}

BerandaViewModel _buildViewModel(Map<String, Object> bodiesByRoute) {
  final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
    ..httpClientAdapter = MockApiAdapter(bodiesByRoute: bodiesByRoute);
  return BerandaViewModel(homeRepository: HomeRepository(ApiClient(dio)));
}
