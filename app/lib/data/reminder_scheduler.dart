import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../model/account.dart';

/// The evening reminder (§7.7) is a local notification, so it fires offline.
/// It is rescheduled whenever the app opens or Settings is saved.
const String reminderTitle = 'MALAS';
const String reminderBody = 'Sudah catat hari ini?';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();
bool _isInitialized = false;

/// Replaces every scheduled reminder with [store]'s. A null [store], after
/// sign-out, leaves none.
Future<void> scheduleReminderOnPhone(Store? store) async {
  await _initialize();
  await _notifications.cancelAll();
  if (store == null) return;
  final slots = reminderSlotsFor(store);
  if (slots.isEmpty) return;
  await _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
  final now = tz.TZDateTime.now(tz.getLocation(store.timezone));
  for (final slot in slots) {
    await _notifications.zonedSchedule(
      id: slot.weekday,
      scheduledDate: nextReminderAt(slot: slot, now: now),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_reminder',
          'Pengingat malam',
        ),
      ),
      // Inexact needs no exact-alarm permission. A few minutes late is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: reminderTitle,
      body: reminderBody,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

/// One weekly reminder: an ISO weekday (1 is Monday) at a time of day.
class ReminderSlot {
  const ReminderSlot({
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final int weekday;
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(weekday, hour, minute);

  @override
  String toString() => 'ReminderSlot($weekday, $hour:$minute)';
}

/// Every open day at the store's reminder time. Closed days get none (§7.7),
/// and a store with the reminder off gets none at all.
List<ReminderSlot> reminderSlotsFor(Store store) {
  final reminderTime = store.reminderTime;
  if (reminderTime == null) return const [];
  final [hour, minute] = reminderTime.split(':').map(int.parse).toList();
  return [
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (!store.closedDays.contains(weekday))
        ReminderSlot(weekday: weekday, hour: hour, minute: minute),
  ];
}

/// The first time [slot] comes round after [now], in [now]'s time zone.
tz.TZDateTime nextReminderAt({
  required ReminderSlot slot,
  required tz.TZDateTime now,
}) {
  var reminderAt = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    slot.hour,
    slot.minute,
  );
  final daysAhead = (slot.weekday - now.weekday) % DateTime.daysPerWeek;
  reminderAt = reminderAt.add(Duration(days: daysAhead));
  if (!reminderAt.isAfter(now)) {
    reminderAt = reminderAt.add(const Duration(days: DateTime.daysPerWeek));
  }
  return reminderAt;
}

Future<void> _initialize() async {
  if (_isInitialized) return;
  timezone_data.initializeTimeZones();
  await _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  _isInitialized = true;
}
