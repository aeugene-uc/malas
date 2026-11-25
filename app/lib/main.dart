import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/auth_repository.dart';
import 'data/draft_repository.dart';
import 'data/reminder_scheduler.dart';
import 'data/store_repository.dart';
import 'data/unsent_drafts_store.dart';
import 'model/account.dart';
import 'data/mock_api_adapter.dart';
import 'data/mock_bodies.dart';
import 'data/mock_transaction_store.dart';
import 'view/first_run/session_gate.dart';
import 'viewmodel/app_shell_view_model.dart';
import 'viewmodel/session_view_model.dart';

/// Empty means the app runs on canned bodies. To use a real backend:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  runApp(MalasApp(apiClient: buildApiClient(baseUrl: apiBaseUrl)));
}

ApiClient buildApiClient({required String baseUrl}) {
  final isMock = baseUrl.isEmpty;
  const mockBasePath = '/api/v1';
  final dio = Dio(
    BaseOptions(
      baseUrl: isMock ? 'http://mock$mockBasePath' : baseUrl,
      connectTimeout: const Duration(seconds: 10),
      // An AI read can take up to 20 s, then the backend retries once (§12).
      receiveTimeout: const Duration(seconds: 45),
      // A photo upload on a weak signal otherwise sat on "Membaca…" for over
      // ten minutes (#464); the compressed photo is well under a megabyte.
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  if (isMock) {
    dio.httpClientAdapter = MockApiAdapter(
      basePath: mockBasePath,
      // A fresh store per app run, so deletes and payments stick while it
      // runs but every start is the same.
      bodiesByRoute: {...mockBodiesByRoute, ...MockTransactionStore().routes},
    );
  }
  return ApiClient(dio);
}

class MalasApp extends StatelessWidget {
  const MalasApp({
    super.key,
    required this.apiClient,
    this.scheduleReminder = scheduleReminderOnPhone,
  });

  final ApiClient apiClient;

  /// Widget tests pass a stand-in, since they have no notification plugin.
  final Future<void> Function(Store? store) scheduleReminder;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider(
          create: (_) => AuthRepository(
            apiClient: apiClient,
            secureStorage: const FlutterSecureStorage(),
          ),
        ),
        Provider(
          create: (_) => StoreRepository(
            apiClient,
            secureStorage: const FlutterSecureStorage(),
          ),
        ),
        Provider(create: (_) => DraftRepository(apiClient)),
        Provider(
          create: (_) => UnsentDraftsStore(const FlutterSecureStorage()),
        ),
        ChangeNotifierProvider(
          create: (context) => _startSession(context, scheduleReminder),
        ),
        ChangeNotifierProvider(create: (_) => AppShellViewModel()),
      ],
      child: MaterialApp(
        title: 'MALAS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        // Indonesian only, so Flutter's own pickers, menus and screen-reader
        // labels match the app's words on any phone (F11, #26).
        supportedLocales: const [Locale('id')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const SessionGate(),
      ),
    );
  }
}

SessionViewModel _startSession(
  BuildContext context,
  Future<void> Function(Store? store) scheduleReminder,
) {
  final session = SessionViewModel(
    authRepository: context.read<AuthRepository>(),
    now: DateTime.now,
    scheduleReminder: scheduleReminder,
  );
  context.read<ApiClient>().onUnauthorized = session.handleUnauthorized;
  final unsentDraftsStore = context.read<UnsentDraftsStore>();
  session.addListener(
    () => unsentDraftsStore.storeId = session.account?.store.id,
  );
  session.start();
  return session;
}
