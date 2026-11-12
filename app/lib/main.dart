import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/draft_repository.dart';
import 'data/mock_api_adapter.dart';
import 'data/mock_bodies.dart';
import 'view/app_shell.dart';
import 'viewmodel/app_shell_view_model.dart';

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
    ),
  );
  if (isMock) {
    dio.httpClientAdapter = MockApiAdapter(
      basePath: mockBasePath,
      bodiesByRoute: mockBodiesByRoute,
    );
  }
  return ApiClient(dio);
}

class MalasApp extends StatelessWidget {
  const MalasApp({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider(create: (_) => DraftRepository(apiClient)),
        ChangeNotifierProvider(create: (_) => AppShellViewModel()),
      ],
      child: MaterialApp(
        title: 'MALAS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: const AppShell(),
      ),
    );
  }
}
