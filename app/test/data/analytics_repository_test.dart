import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/analytics_repository.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/analytics.dart';

import '../support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;
  late AnalyticsRepository repository;
  final november = PeriodRange.containing(
    period: AnalyticsPeriod.bulan,
    date: DateTime(2026, 11, 15),
  );

  setUp(() {
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    repository = AnalyticsRepository(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
      ),
    );
  });

  test('asksForThePeriodByItsKindAndFirstDay', () async {
    await repository.fetchSummary(november);

    expect(adapter.lastRequest.path, '/analytics/summary');
    expect(adapter.lastRequest.queryParameters, {
      'period': 'bulan',
      'from': '2026-11-01',
    });
  });

  test('ranksMoneyInByItemAndMoneyOutByCategory', () async {
    final masukRows = await repository.fetchMasukByItem(november);
    expect(adapter.lastRequest.queryParameters['direction'], 'IN');

    final keluarRows = await repository.fetchKeluarByCategory(november);
    expect(adapter.lastRequest.queryParameters['direction'], 'OUT');

    expect(masukRows.first.name, 'Nasi goreng');
    expect(masukRows.first.share, 0.52);
    expect(keluarRows.first.name, 'Bahan');
  });

  test('readsTheAlertList', () async {
    final alerts = await repository.fetchAlerts();

    expect(alerts.single.message, 'Gas naik 12% dari pembelian terakhir');
  });
}
