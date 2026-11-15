import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/account.dart';

void main() {
  test('readsTheOwnerAndTheirStore', () {
    final account = Account.fromJson(
      mockBodiesByRoute['GET /auth/me']! as Map<String, Object?>,
    );

    expect(account.user.phone, '+6281234567890');
    expect(account.store.businessTypes, {BusinessType.makananMinuman});
    expect(account.store.plan, Plan.gratis);
    expect(account.isSetUp, isTrue);
  });

  test('isNotSetUpUntilTheOwnerConsents', () {
    const store = Store(
      id: 'store-1',
      name: 'Warung Bu Sari',
      businessTypes: {BusinessType.makananMinuman},
      plan: Plan.gratis,
      trialEndsAt: null,
    );
    User userWithConsent(String? consentAt) => User(
      id: 'user-1',
      name: 'Bu Sari',
      phone: '+6281234567890',
      consentAt: consentAt,
    );

    expect(Account(user: userWithConsent(null), store: store).isSetUp, isFalse);
    expect(
      Account(
        user: userWithConsent('2026-11-15T09:00:00Z'),
        store: store,
      ).isSetUp,
      isTrue,
    );
  });

  test('theTrialIsOverOnlyAfterItsEndOnTheFreePlan', () {
    final trialEndsAt = DateTime.utc(2026, 11, 25);
    Store storeOn(Plan plan) => Store(
      id: 'store-1',
      name: 'Warung',
      businessTypes: const {BusinessType.jasa},
      plan: plan,
      trialEndsAt: trialEndsAt,
    );
    final dayBefore = DateTime.utc(2026, 11, 24);
    final dayAfter = DateTime.utc(2026, 11, 26);

    expect(storeOn(Plan.gratis).isTrialOverAt(dayBefore), isFalse);
    expect(storeOn(Plan.gratis).isTrialOverAt(dayAfter), isTrue);
    expect(storeOn(Plan.pro).isTrialOverAt(dayAfter), isFalse);
  });

  test('rejectsAnUnknownBusinessType', () {
    expect(() => BusinessType.fromWire('WARNET'), throwsFormatException);
  });
}
