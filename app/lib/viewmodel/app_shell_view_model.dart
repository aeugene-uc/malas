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

class AppShellViewModel extends ChangeNotifier {
  AppTab _selectedTab = AppTab.beranda;

  AppTab get selectedTab => _selectedTab;

  void selectTab(AppTab tab) {
    if (tab == _selectedTab) return;
    _selectedTab = tab;
    notifyListeners();
  }
}
