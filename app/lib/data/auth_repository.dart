import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../model/account.dart';
import 'api_client.dart';

/// Sign-in, first-run setup and consent. The token is kept encrypted on the
/// phone, so the owner signs in once.
class AuthRepository {
  AuthRepository({required this._apiClient, required this._secureStorage});

  static const String tokenKey = 'token';
  static const String trialSheetSeenKey = 'trialSheetSeen';

  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;

  /// Null when no token is saved. A saved token the server no longer accepts
  /// surfaces as an [ApiException] with status 401.
  Future<Account?> restoreSession() async {
    final token = await _secureStorage.read(key: tokenKey);
    if (token == null) return null;
    _apiClient.token = token;
    return fetchAccount();
  }

  Future<Account> fetchAccount() async {
    final body = await _apiClient.get('/auth/me');
    return Account.fromJson(body as Map<String, Object?>);
  }

  /// [phone] goes as typed. The server turns it into E.164.
  Future<Account> signIn({required String phone, required String password}) {
    return _startSession(
      path: '/auth/login',
      body: {'phone': phone, 'password': password},
    );
  }

  Future<Account> register({
    required String name,
    required String phone,
    required String password,
  }) {
    return _startSession(
      path: '/auth/register',
      body: {'name': name, 'phone': phone, 'password': password},
    );
  }

  Future<void> signOut() async {
    _apiClient.token = null;
    await _secureStorage.delete(key: tokenKey);
  }

  Future<void> saveStoreSetup({
    required String storeId,
    required String storeName,
    required Set<BusinessType> businessTypes,
  }) async {
    await _apiClient.patch(
      '/stores/$storeId',
      body: {
        'name': storeName,
        'businessTypes': [for (final type in businessTypes) type.wireValue],
      },
    );
  }

  Future<void> giveConsent() async {
    await _apiClient.post('/auth/consent');
  }

  Future<void> choosePlan({required String storeId, required Plan plan}) async {
    await _apiClient.patch('/stores/$storeId', body: {'plan': plan.wireValue});
  }

  Future<bool> hasSeenTrialSheet() async {
    return await _secureStorage.read(key: trialSheetSeenKey) != null;
  }

  Future<void> markTrialSheetSeen() async {
    await _secureStorage.write(key: trialSheetSeenKey, value: 'true');
  }

  Future<Account> _startSession({
    required String path,
    required Map<String, Object?> body,
  }) async {
    final response = await _apiClient.post(path, body: body);
    final responseJson = response as Map<String, Object?>;
    final token = responseJson['token'] as String;
    await _secureStorage.write(key: tokenKey, value: token);
    _apiClient.token = token;
    return Account.fromJson(responseJson);
  }
}
