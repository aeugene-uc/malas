import '../model/analytics.dart';
import '../model/home.dart';
import 'api_client.dart';

/// Analisis (§7.6). Every figure is computed by the server per §10.
class AnalyticsRepository {
  AnalyticsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AnalyticsSummary> fetchSummary(PeriodRange range) async {
    final body = await _apiClient.get(
      '/analytics/summary',
      query: _periodQuery(range),
    );
    return AnalyticsSummary.fromJson(body as Map<String, Object?>);
  }

  /// Money in by item.
  Future<List<RankedRow>> fetchMasukByItem(PeriodRange range) {
    return _fetchRows(
      path: '/analytics/by-item',
      query: {..._periodQuery(range), 'direction': 'IN'},
    );
  }

  /// Money out by category and expense item.
  Future<List<RankedRow>> fetchKeluarByCategory(PeriodRange range) {
    return _fetchRows(
      path: '/analytics/by-category',
      query: {..._periodQuery(range), 'direction': 'OUT'},
    );
  }

  Future<List<HomeAlert>> fetchAlerts() async {
    final body = await _apiClient.get('/alerts') as Map<String, Object?>;
    final alertsJson = body['alerts'] as List<Object?>;
    return [
      for (final alertJson in alertsJson)
        HomeAlert.fromJson(alertJson as Map<String, Object?>),
    ];
  }

  Future<List<RankedRow>> _fetchRows({
    required String path,
    required Map<String, Object?> query,
  }) async {
    final body =
        await _apiClient.get(path, query: query) as Map<String, Object?>;
    final rowsJson = body['rows'] as List<Object?>;
    return [
      for (final rowJson in rowsJson)
        RankedRow.fromJson(rowJson as Map<String, Object?>),
    ];
  }
}

Map<String, Object?> _periodQuery(PeriodRange range) {
  return {'period': range.period.wireValue, 'from': range.fromWire};
}
