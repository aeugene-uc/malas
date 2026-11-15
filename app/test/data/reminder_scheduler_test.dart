import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/reminder_scheduler.dart';
import 'package:malas/model/account.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  Store storeWith({String? reminderTime, Set<int> closedDays = const {}}) {
    return Store(
      id: 'store-1',
      name: 'Warung Bu Sari',
      businessTypes: const {BusinessType.makananMinuman},
      plan: Plan.gratis,
      trialEndsAt: null,
      closedDays: closedDays,
      reminderTime: reminderTime,
    );
  }

  test('remindsEveryOpenDayButNotOnClosedDays', () {
    final slots = reminderSlotsFor(
      storeWith(reminderTime: '20:30', closedDays: {DateTime.sunday}),
    );

    expect(slots.map((slot) => slot.weekday), [1, 2, 3, 4, 5, 6]);
    expect(
      slots.first,
      const ReminderSlot(weekday: DateTime.monday, hour: 20, minute: 30),
    );
  });

  test('remindsNeverWhenTheReminderIsOff', () {
    expect(reminderSlotsFor(storeWith(reminderTime: null)), isEmpty);
  });

  group('nextReminderAt', () {
    tz.Location jakarta() => tz.getLocation('Asia/Jakarta');

    // Sunday 15 Nov 2026.
    tz.TZDateTime sundayAt(int hour) =>
        tz.TZDateTime(jakarta(), 2026, 11, 15, hour);

    test('isLaterTodayWhenTodaysTimeIsStillAhead', () {
      final reminderAt = nextReminderAt(
        slot: const ReminderSlot(weekday: DateTime.sunday, hour: 20, minute: 0),
        now: sundayAt(9),
      );

      expect(reminderAt, tz.TZDateTime(jakarta(), 2026, 11, 15, 20));
    });

    test('isNextWeekWhenTodaysTimeHasPassed', () {
      final reminderAt = nextReminderAt(
        slot: const ReminderSlot(weekday: DateTime.sunday, hour: 20, minute: 0),
        now: sundayAt(21),
      );

      expect(reminderAt, tz.TZDateTime(jakarta(), 2026, 11, 22, 20));
    });

    test('isTheComingWeekdayForAnotherDay', () {
      final reminderAt = nextReminderAt(
        slot: const ReminderSlot(weekday: DateTime.monday, hour: 20, minute: 0),
        now: sundayAt(21),
      );

      expect(reminderAt, tz.TZDateTime(jakarta(), 2026, 11, 16, 20));
    });
  });
}
