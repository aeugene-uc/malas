import 'package:dio/dio.dart';

/// The only class in the app that talks HTTP. Repositories call it and turn
/// the decoded JSON into models.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;
  String? _token;

  /// Set after sign-in. Every later request carries it as a bearer token.
  set token(String? token) => _token = token;

  Future<Object?> get(String path, {Map<String, Object?>? query}) {
    return _send(method: 'GET', path: path, query: query);
  }

  /// [idempotencyKey] is required by `POST /transactions`, so a retried
  /// Simpan on a bad connection cannot record the same sale twice.
  Future<Object?> post(String path, {Object? body, String? idempotencyKey}) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Object?> patch(String path, {Object? body}) {
    return _send(method: 'PATCH', path: path, body: body);
  }

  Future<Object?> delete(String path) {
    return _send(method: 'DELETE', path: path);
  }

  Future<Object?> _send({
    required String method,
    required String path,
    Map<String, Object?>? query,
    Object? body,
    String? idempotencyKey,
  }) async {
    final headers = <String, Object>{
      if (_token != null) 'Authorization': 'Bearer $_token',
      'Idempotency-Key': ?idempotencyKey,
    };
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

/// A failed request, in the backend's error shape:
/// `{"error": {"code", "message", "fields"}}`. [message] is Indonesian and
/// can be shown to the owner as it is.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.messageByField = const {},
  });

  factory ApiException.fromDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final errorBody = _readErrorBody(error.response?.data);
    if (errorBody == null) {
      return ApiException(
        code: statusCode == null ? 'NETWORK' : 'HTTP_$statusCode',
        message: statusCode == null
            ? 'Tidak ada koneksi'
            : 'Terjadi kesalahan ($statusCode)',
        statusCode: statusCode,
      );
    }
    final fields = errorBody['fields'];
    return ApiException(
      code: errorBody['code'] as String,
      message: errorBody['message'] as String,
      statusCode: statusCode,
      messageByField: fields is Map
          ? fields.map((field, text) => MapEntry('$field', '$text'))
          : const {},
    );
  }

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, String> messageByField;

  /// No response at all, as opposed to the server answering with an error.
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

Map<String, Object?>? _readErrorBody(Object? responseData) {
  if (responseData is! Map) return null;
  final errorBody = responseData['error'];
  if (errorBody is! Map) return null;
  if (errorBody['code'] is! String || errorBody['message'] is! String) {
    return null;
  }
  return errorBody.cast<String, Object?>();
}
