import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error code Synology answers when a request carries no valid session.
const int kSynologyNoSession = 119;

/// Error code for a missing permission, e.g. a download from a view-only
/// share or an item that no longer exists.
const int kSynologyPermissionDenied = 804;

/// Why a Synology share request failed.
enum SynologyShareErrorKind {
  /// No password stored, or the share rejected it.
  wrongPassword,

  /// The session is gone (expired, or replaced by another login).
  noSession,

  /// The share answered, but not in the shape this client understands.
  unexpected,

  /// No answer at all.
  unreachable,
}

class SynologyShareException implements Exception {
  const SynologyShareException(this.kind, this.message, {this.code});

  final SynologyShareErrorKind kind;
  final String message;

  /// Synology's error code, when the share sent one.
  final int? code;

  @override
  String toString() => 'SynologyShareException($kind, $message, code: $code)';
}

/// Decodes Synology's `{"success": ..., "data": ..., "error": {"code": n}}`
/// envelope and returns `data`. Synology reports most failures as HTTP 200
/// with `success: false`, so the status code alone says little.
///
/// Throws [SynologyShareException]: [SynologyShareErrorKind.noSession] for
/// error 119, [SynologyShareErrorKind.unexpected] for anything else that is
/// not a successful envelope.
Map<String, Object?> decodeSynologyEnvelope(http.Response response) {
  if (response.statusCode != 200) {
    throw SynologyShareException(
      SynologyShareErrorKind.unexpected,
      'HTTP ${response.statusCode}',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } on FormatException {
    throw const SynologyShareException(
      SynologyShareErrorKind.unexpected,
      'The server did not answer like Synology Photos',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const SynologyShareException(
      SynologyShareErrorKind.unexpected,
      'The server did not answer like Synology Photos',
    );
  }
  if (decoded['success'] == true) {
    final data = decoded['data'];
    return data is Map<String, Object?> ? data : const {};
  }
  final error = decoded['error'];
  final code = error is Map<String, Object?> && error['code'] is int
      ? error['code'] as int
      : null;
  if (code == kSynologyNoSession) {
    throw const SynologyShareException(
      SynologyShareErrorKind.noSession,
      'The share session is no longer valid',
      code: kSynologyNoSession,
    );
  }
  throw SynologyShareException(
    SynologyShareErrorKind.unexpected,
    'Synology error ${code ?? 'unknown'}',
    code: code,
  );
}

/// Whether [response] is Synology's JSON error envelope rather than media
/// bytes. Image and download endpoints answer errors as HTTP 200 JSON.
bool isSynologyJsonResponse(String? contentType) =>
    contentType != null && contentType.toLowerCase().contains('json');
