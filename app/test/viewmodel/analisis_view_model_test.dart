import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/analytics_repository.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/analytics.dart';
import 'package:malas/viewmodel/analisis_view_model.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;

  AnalisisViewModel buildViewModel({Map<String, Object>? bodiesByRoute}) {
    adapter = RecordingAdapter(
      bodiesByRoute: bodiesByRoute ?? mockBodiesByRoute,
    );
    return AnalisisViewModel(
      analyticsRepository: AnalyticsRepository(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
        ),
      ),
      today: () => DateTime(2026, 11, 15),
    );
  }

  test('opensOnThisMonthWithEverySectionLoaded', () async {
    final viewModel = buildViewModel();

    await viewModel.load();

    expect(viewModel.range.fromWire, '2026-11-01');
    expect(viewModel.summary!.masuk, 8640000);
    expect(viewModel.masukRows, hasLength(3));
    expect(viewModel.keluarRows, hasLength(3));
    expect(viewModel.alerts, hasLength(1));
    expect(viewModel.isLoading, isFalse);
  });

  test('switchingToMingguAsksForThisWeek', () async {
    final viewModel = buildViewModel();

    await viewModel.selectPeriod(AnalyticsPeriod.minggu);

    final summaryRequest = adapter.requests.firstWhere(
      (request) => request.path == '/analytics/summary',
    );
    expect(summaryRequest.queryParameters, {
      'period': 'minggu',
      'from': '2026-11-09',
    });
  });

  test('cannotStepPastThePeriodHoldingToday', () async {
    final viewModel = buildViewModel();
    expect(viewModel.hasNext, isFalse);

    await viewModel.showNext();
    expect(viewModel.range.fromWire, '2026-11-01');
    expect(adapter.requests, isEmpty);

    await viewModel.showPrevious();
    expect(viewModel.range.fromWire, '2026-10-01');
    expect(viewModel.hasNext, isTrue);
  });

  test('showsTheServerMessageWhenAnalisisFailsToLoad', () async {
    final viewModel = buildViewModel(bodiesByRoute: const {});

    await viewModel.load();

    expect(viewModel.errorMessage, contains('/analytics/summary'));
    expect(viewModel.isLoading, isFalse);
  });
}
