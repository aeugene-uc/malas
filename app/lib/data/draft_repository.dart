import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../model/draft.dart';
import '../model/transaction.dart';
import 'api_client.dart';

class DraftRepository {
  DraftRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AiReadResult> readTranscript(String transcript) async {
    final body = await _apiClient.post(
      '/ai/read',
      body: {'kind': 'VOICE', 'transcript': transcript},
    );
    return AiReadResult.fromJson(body as Map<String, Object?>);
  }

  /// The server compares [imageHash] with earlier photos, so the same nota
  /// sent twice gets a soft duplicate warning (§7.3).
  Future<AiReadResult> readPhoto({
    required PhotoKind kind,
    required Uint8List imageBytes,
  }) async {
    final imageHash = sha256.convert(imageBytes).toString();
    final form = FormData.fromMap({
      'kind': kind.wireValue,
      'imageHash': imageHash,
      'image': MultipartFile.fromBytes(imageBytes, filename: 'foto.jpg'),
    });
    final body = await _apiClient.post('/ai/read', body: form);
    return AiReadResult.fromJson(body as Map<String, Object?>);
  }

  /// Simpan. Retrying with the same [idempotencyKey] replays the first save
  /// instead of recording the sale twice.
  Future<SaveResult> save(Draft draft, {required String idempotencyKey}) async {
    final body = await _apiClient.post(
      '/transactions',
      body: draft.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return SaveResult.fromJson(body as Map<String, Object?>);
  }

  /// Batal on the toast after Simpan. The server soft-deletes, so nothing is
  /// lost if the owner meant to keep it after all.
  Future<void> delete(String transactionId) async {
    await _apiClient.delete('/transactions/$transactionId');
  }
}

/// What `POST /transactions` returns: the saved row plus the non-blocking
/// warnings the server raised (§5.4).
class SaveResult {
  const SaveResult({required this.transaction, required this.warnings});

  factory SaveResult.fromJson(Map<String, Object?> json) {
    final warningsJson = json['warnings'] as List<Object?>? ?? const [];
    return SaveResult(
      transaction: Transaction.fromJson(
        json['transaction'] as Map<String, Object?>,
      ),
      warnings: [
        for (final warningJson in warningsJson)
          SaveWarning.fromJson(warningJson as Map<String, Object?>),
      ],
    );
  }

  final Transaction transaction;
  final List<SaveWarning> warnings;
}

class SaveWarning {
  const SaveWarning({
    required this.code,
    required this.message,
    required this.lineId,
  });

  factory SaveWarning.fromJson(Map<String, Object?> json) {
    return SaveWarning(
      code: json['code'] as String,
      message: json['message'] as String,
      lineId: json['lineId'] as String?,
    );
  }

  final String code;
  final String message;
  final String? lineId;
}

/// A random version 4 UUID. One is made when a draft opens and reused on
/// every retry of its Simpan.
String generateIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
