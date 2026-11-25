import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers requests from canned bodies instead of the network, so screens
/// can be built before the backend routes exist. A route key is
/// `"METHOD /path"`, and a path segment starting with `:` matches any value
/// (`"GET /transactions/:id"`).
///
/// A route's value is either a fixed body or a [MockHandler], which builds
/// the body from the request, so a mock can remember a delete or a payment.
class MockApiAdapter implements HttpClientAdapter {
  MockApiAdapter({required this.bodiesByRoute, this.basePath = ''});

  final Map<String, Object> bodiesByRoute;

  /// Stripped from the request path before matching, e.g. `/api/v1`.
  final String basePath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final requestPath = _stripBasePath(options.uri.path);
    final routeKey = _findRouteKey(method: options.method, path: requestPath);
    if (routeKey == null) {
      return _jsonResponse(404, {
        'error': {
          'code': 'MOCK_MISSING',
          'message': 'Mock belum ada: ${options.method} $requestPath',
        },
      });
    }
    final statusCode = options.method == 'POST' ? 201 : 200;
    final body = switch (bodiesByRoute[routeKey]!) {
      final MockHandler handler => handler(
        MockRequest(path: requestPath, options: options),
      ),
      final fixedBody => fixedBody,
    };
    return _jsonResponse(statusCode, body);
  }

  @override
  void close({bool force = false}) {}

  String _stripBasePath(String path) {
    return path.startsWith(basePath) ? path.substring(basePath.length) : path;
  }

  String? _findRouteKey({required String method, required String path}) {
    final requestSegments = path.split('/');
    for (final routeKey in bodiesByRoute.keys) {
      final [routeMethod, routePath] = routeKey.split(' ');
      if (routeMethod != method) continue;
      if (_isPathMatch(routePath.split('/'), requestSegments)) return routeKey;
    }
    return null;
  }
}

bool _isPathMatch(List<String> routeSegments, List<String> requestSegments) {
  if (routeSegments.length != requestSegments.length) return false;
  for (var index = 0; index < routeSegments.length; index++) {
    final routeSegment = routeSegments[index];
    final isParameter = routeSegment.startsWith(':');
    if (!isParameter && routeSegment != requestSegments[index]) return false;
  }
  return true;
}

ResponseBody _jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Builds a mock reply from the request.
typedef MockHandler = Object Function(MockRequest request);

class MockRequest {
  const MockRequest({required this.path, required this.options});

  /// The path without the base path, e.g. `/transactions/trx-1/restore`.
  final String path;
  final RequestOptions options;

  Map<String, Object?> get query => options.queryParameters;

  Map<String, Object?> get body =>
      (options.data as Map<String, Object?>?) ?? const {};

  /// The path segment after [segment], e.g. the id after `transactions`.
  String segmentAfter(String segment) {
    final segments = path.split('/');
    return segments[segments.indexOf(segment) + 1];
  }
}
