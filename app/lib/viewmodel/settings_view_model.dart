import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/store_repository.dart';
import '../model/account.dart';

/// Settings (§6): jenis usaha, closed days, day-change hour, evening
/// reminder and alerts. Edits stay on screen until Simpan.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required Account account, required this._storeRepository})
    : _account = account,
      _savedStore = account.store,
      _businessTypes = {...account.store.businessTypes},
      _closedDays = {...account.store.closedDays},
      _dayChangeHour = account.store.dayChangeHour,
      _reminderTime = account.store.reminderTime,
      _isAlertsOn = account.store.isAlertsOn;

  /// The day-change hours offered: a night stall closing at 3 still counts
  /// its sales on the evening's date.
  static const List<int> dayChangeHours = [0, 1, 2, 3, 4, 5, 6];
  static const String defaultReminderTime = '20:00';

  final StoreRepository _storeRepository;
  final Account _account;
  final Store _savedStore;

  final Set<BusinessType> _businessTypes;
  final Set<int> _closedDays;
  int _dayChangeHour;
  String? _reminderTime;
  bool _isAlertsOn;
  bool _isSaving = false;
  String? _errorMessage;

  Set<BusinessType> get businessTypes => Set.unmodifiable(_businessTypes);
  Set<int> get closedDays => Set.unmodifiable(_closedDays);
  int get dayChangeHour => _dayChangeHour;
  String? get reminderTime => _reminderTime;
  bool get isReminderOn => _reminderTime != null;
  bool get isAlertsOn => _isAlertsOn;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  Plan get plan => _savedStore.plan;

  bool get hasChanges =>
      !setEquals(_businessTypes, _savedStore.businessTypes) ||
      !setEquals(_closedDays, _savedStore.closedDays) ||
      _dayChangeHour != _savedStore.dayChangeHour ||
      _reminderTime != _savedStore.reminderTime ||
      _isAlertsOn != _savedStore.isAlertsOn;

  void toggleBusinessType(BusinessType type) {
    if (!_businessTypes.remove(type)) _businessTypes.add(type);
    _changed();
  }

  /// [weekday] is an ISO weekday, 1 for Monday.
  void toggleClosedDay(int weekday) {
    if (!_closedDays.remove(weekday)) _closedDays.add(weekday);
    _changed();
  }

  void selectDayChangeHour(int hour) {
    _dayChangeHour = hour;
    _changed();
  }

  void setReminderOn(bool isOn) {
    _reminderTime = isOn
        ? (_savedStore.reminderTime ?? defaultReminderTime)
        : null;
    _changed();
  }

  /// [time] is `"HH:mm"`.
  void selectReminderTime(String time) {
    _reminderTime = time;
    _changed();
  }

  void setAlertsOn(bool isOn) {
    _isAlertsOn = isOn;
    _changed();
  }

  /// Returns the account with the saved settings, or null with
  /// [errorMessage] saying why.
  Future<Account?> save() async {
    if (_businessTypes.isEmpty) {
      _errorMessage = 'Pilih jenis usaha';
      notifyListeners();
      return null;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _storeRepository.saveSettings(
        storeId: _savedStore.id,
        businessTypes: _businessTypes,
        closedDays: _closedDays,
        dayChangeHour: _dayChangeHour,
        reminderTime: _reminderTime,
        isAlertsOn: _isAlertsOn,
      );
      return Account(
        user: _account.user,
        store: _savedStore.withSettings(
          businessTypes: {..._businessTypes},
          closedDays: {..._closedDays},
          dayChangeHour: _dayChangeHour,
          reminderTime: _reminderTime,
          isAlertsOn: _isAlertsOn,
        ),
      );
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _changed() {
    _errorMessage = null;
    notifyListeners();
  }
}
