import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/auth_repository.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/account.dart';
import 'package:malas/viewmodel/session_view_model.dart';

import '../support/recording_adapter.dart';
import '../support/status_adapter.dart';

final DateTime beforeTrialEnds = DateTime.utc(2026, 11, 20);
final DateTime afterTrialEnds = DateTime.utc(2099, 1, 2);

void main() {
  late RecordingAdapter adapter;
  late List<Store?> scheduledReminders;

  SessionViewModel buildSession({
    required DateTime now,
    HttpClientAdapter? httpAdapter,
  }) {
    adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    scheduledReminders = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
      ..httpClientAdapter = httpAdapter ?? adapter;
    return SessionViewModel(
      authRepository: AuthRepository(
        apiClient: ApiClient(dio),
        secureStorage: const FlutterSecureStorage(),
      ),
      now: () => now,
      scheduleReminder: (store) async => scheduledReminders.add(store),
    );
  }

  test('startsOnSignInWithoutASavedToken', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = buildSession(now: beforeTrialEnds);

    await session.start();

    expect(session.stage, SessionStage.signedOut);
  });

  test('startsOnTheTabsWithASavedTokenForASetUpStore', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(now: beforeTrialEnds);

    await session.start();

    expect(session.stage, SessionStage.ready);
    expect(session.isTrialSheetDue, isFalse);
  });

  test('forgetsARejectedTokenAndStartsOnSignIn', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(
      now: beforeTrialEnds,
      httpAdapter: StatusAdapter(401),
    );

    await session.start();

    expect(session.stage, SessionStage.signedOut);
    expect(
      await const FlutterSecureStorage().read(key: AuthRepository.tokenKey),
      isNull,
    );
  });

  test('showsTheServerMessageWhenStartUpFailsForAnotherReason', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(
      now: beforeTrialEnds,
      httpAdapter: StatusAdapter(500),
    );

    await session.start();

    expect(session.stage, SessionStage.failed);
    expect(session.errorMessage, 'Server sedang bermasalah');
  });

  test('aNewOwnerGoesToFirstRunSetup', () async {
    final session = buildSession(now: beforeTrialEnds);
    final newAccount = Account.fromJson(
      mockBodiesByRoute['POST /auth/register']! as Map<String, Object?>,
    );

    await session.enter(newAccount);

    expect(session.stage, SessionStage.firstRun);
  });

  test('aRejectedTokenLaterSendsTheOwnerBackToSignIn', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(now: beforeTrialEnds);
    await session.start();

    await session.handleUnauthorized();

    expect(session.stage, SessionStage.signedOut);
    expect(session.account, isNull);
  });

  test('showsTheTrialSheetOnceAfterTheTrialEnds', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(now: afterTrialEnds);
    await session.start();
    expect(session.isTrialSheetDue, isTrue);

    await session.answerTrialSheet(Plan.gratis);
    await session.start();

    expect(session.isTrialSheetDue, isFalse);
  });

  test('setsTheEveningReminderForASetUpStore', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(now: beforeTrialEnds);

    await session.start();

    expect(scheduledReminders.single!.reminderTime, '20:00');
  });

  test('clearsTheEveningReminderOnKeluar', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(now: beforeTrialEnds);
    await session.start();

    await session.signOut();

    expect(scheduledReminders.last, isNull);
  });

  test('pilihProRecordsTheChoiceOnTheStore', () async {
    FlutterSecureStorage.setMockInitialValues({AuthRepository.tokenKey: 't'});
    final session = buildSession(now: afterTrialEnds);
    await session.start();

    await session.answerTrialSheet(Plan.pro);

    expect(adapter.lastRequest.method, 'PATCH');
    expect(adapter.lastRequest.path, '/stores/store-1');
    expect(adapter.lastRequest.data, {'plan': 'PRO'});
  });
}
