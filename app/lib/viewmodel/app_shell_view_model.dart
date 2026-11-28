import 'package:flutter/foundation.dart';

/// The four tabs of spec §6, in bottom-bar order.
enum AppTab {
  beranda('Beranda'),
  catatan('Catatan'),
  analisis('Analisis'),
  tanya('Tanya');

  const AppTab(this.label);

  final String label;
}

/// The three ways to record, reached from the nav mic (§4.1).
enum CaptureMode { bicara, foto, ketik }

class AppShellViewModel extends ChangeNotifier {
  AppTab _selectedTab = AppTab.beranda;
  CaptureMode? _pendingCapture;

  AppTab get selectedTab => _selectedTab;

  void selectTab(AppTab tab) {
    if (tab == _selectedTab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  /// The mic works from every tab, but recording needs Beranda's business
  /// date, so Beranda opens and runs it.
  void requestCapture(CaptureMode mode) {
    _selectedTab = AppTab.beranda;
    _pendingCapture = mode;
    notifyListeners();
  }

  /// Hands the requested capture over once, to Beranda.
  CaptureMode? takePendingCapture() {
    final mode = _pendingCapture;
    _pendingCapture = null;
    return mode;
  }
}
