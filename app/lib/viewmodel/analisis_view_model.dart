import 'package:flutter/foundation.dart';

import '../data/analytics_repository.dart';
import '../data/api_client.dart';
import '../model/analytics.dart';
import '../model/home.dart';

/// Analisis (§7.6): one period at a time, its summary, two ranked lists and
/// the alert list. The line chart and rank change are cut for the MVP (#80).
class AnalisisViewModel extends ChangeNotifier {
  AnalisisViewModel({required this._analyticsRepository, required this._today})
    : _range = PeriodRange.containing(
        period: AnalyticsPeriod.bulan,
        date: _today(),
      );

  final AnalyticsRepository _analyticsRepository;

  /// The phone's date, used only to place the first period and to stop
  /// stepping into the future.
  final DateTime Function() _today;

  PeriodRange _range;
  AnalyticsSummary? _summary;
  List<RankedRow> _masukRows = const [];
  List<RankedRow> _keluarRows = const [];
  List<HomeAlert> _alerts = const [];
  bool _isLoading = false;
  String? _errorMessage;

  PeriodRange get range => _range;
  AnalyticsSummary? get summary => _summary;
  List<RankedRow> get masukRows => _masukRows;
  List<RankedRow> get keluarRows => _keluarRows;
  List<HomeAlert> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The current period is the last one with anything to show.
  bool get hasNext => !_range.contains(_today());

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final requestedRange = _range;
    try {
      final summary = await _analyticsRepository.fetchSummary(requestedRange);
      final masukRows = await _analyticsRepository.fetchMasukByItem(
        requestedRange,
      );
      final keluarRows = await _analyticsRepository.fetchKeluarByCategory(
        requestedRange,
      );
      final alerts = await _analyticsRepository.fetchAlerts();
      // A slower reply for a period the owner already left is dropped.
      if (requestedRange != _range) return;
      _summary = summary;
      _masukRows = masukRows;
      _keluarRows = keluarRows;
      _alerts = alerts;
    } on ApiException catch (error) {
      if (requestedRange != _range) return;
      _errorMessage = error.message;
    } finally {
      if (requestedRange == _range) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectPeriod(AnalyticsPeriod period) {
    _range = PeriodRange.containing(period: period, date: _today());
    return load();
  }

  Future<void> showPrevious() {
    _range = _range.previous;
    return load();
  }

  Future<void> showNext() {
    if (!hasNext) return Future.value();
    _range = _range.next;
    return load();
  }
}
