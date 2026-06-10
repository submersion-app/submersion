import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure-function AWS Signature Version 4 signing for S3-compatible services.
///
/// No I/O and no clock access: the request time is always a parameter, so
/// every function is deterministic and testable against AWS's published
/// worked examples (see sigv4_signer_test.dart for vector sources).
class SigV4Signer {
  SigV4Signer._();

  static const _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  static String hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String hexSha256(List<int> bytes) => sha256.convert(bytes).toString();

  static List<int> hmacSha256(List<int> key, List<int> message) =>
      Hmac(sha256, key).convert(message).bytes;

  /// kSigning = HMAC(HMAC(HMAC(HMAC("AWS4"+secret, date), region), service),
  /// "aws4_request") -- the SigV4 key-derivation chain.
  static List<int> deriveSigningKey({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    String service = 's3',
  }) {
    final kDate = hmacSha256(
      utf8.encode('AWS4$secretAccessKey'),
      utf8.encode(dateStamp),
    );
    final kRegion = hmacSha256(kDate, utf8.encode(region));
    final kService = hmacSha256(kRegion, utf8.encode(service));
    return hmacSha256(kService, utf8.encode('aws4_request'));
  }

  /// `20130524T000000Z` -- the x-amz-date header format.
  static String amzDateFormat(DateTime time) {
    final t = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}T${p2(t.hour)}${p2(t.minute)}${p2(t.second)}Z';
  }

  /// `20130524` -- the credential-scope date.
  static String dateStampFormat(DateTime time) {
    final t = time.toUtc();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}';
  }

  /// RFC 3986 encoding as SigV4 requires it: unreserved characters pass
  /// through, everything else becomes uppercase %XX; '/' survives only when
  /// [encodeSlash] is false (object-key paths).
  static String uriEncode(String input, {bool encodeSlash = true}) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(input)) {
      final char = String.fromCharCode(byte);
      if (_unreserved.contains(char) || (char == '/' && !encodeSlash)) {
        buffer.write(char);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }

  /// Query parameters sorted by key, each key and value uriEncoded.
  /// Callers must use unique, unreserved-ASCII keys (true for every
  /// operation this client issues); the sort happens on raw keys.
  static String canonicalQueryString(Map<String, String> queryParams) {
    final keys = queryParams.keys.toList()..sort();
    return keys
        .map((k) => '${uriEncode(k)}=${uriEncode(queryParams[k]!)}')
        .join('&');
  }

  /// The canonical request text: method, encoded path, canonical query
  /// string, canonical headers (lowercased, trimmed, sorted), signed-header
  /// list, payload hash. [headers] must already include `host`.
  static String canonicalRequest({
    required String method,
    required String canonicalUri,
    required Map<String, String> queryParams,
    required Map<String, String> headers,
    required String payloadHash,
  }) {
    final normalized = <String, String>{
      for (final entry in headers.entries)
        entry.key.toLowerCase().trim(): entry.value.trim(),
    };
    final names = normalized.keys.toList()..sort();
    final canonicalHeaders = names.map((n) => '$n:${normalized[n]}\n').join();
    final signedHeaders = names.join(';');
    return [
      method,
      canonicalUri,
      canonicalQueryString(queryParams),
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
  }

  static String stringToSign({
    required String amzDate,
    required String credentialScope,
    required String canonicalRequestStr,
  }) {
    return [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      hexSha256(utf8.encode(canonicalRequestStr)),
    ].join('\n');
  }

  /// Signs one request and returns the headers to send: `host`,
  /// `x-amz-date`, `x-amz-content-sha256`, every entry of [extraHeaders]
  /// (lowercased), and `authorization`. All returned header names are
  /// lowercase; HTTP header names are case-insensitive.
  static Map<String, String> sign({
    required String method,
    required String host,
    required String canonicalUri,
    Map<String, String> queryParams = const {},
    Map<String, String> extraHeaders = const {},
    required List<int> payload,
    required String accessKeyId,
    required String secretAccessKey,
    required String region,
    required DateTime requestTime,
    String service = 's3',
  }) {
    final amzDate = amzDateFormat(requestTime);
    final dateStamp = dateStampFormat(requestTime);
    final payloadHash = hexSha256(payload);

    final headers = <String, String>{
      'host': host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      for (final entry in extraHeaders.entries)
        entry.key.toLowerCase(): entry.value,
    };

    final canonical = canonicalRequest(
      method: method,
      canonicalUri: canonicalUri,
      queryParams: queryParams,
      headers: headers,
      payloadHash: payloadHash,
    );

    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final sts = stringToSign(
      amzDate: amzDate,
      credentialScope: credentialScope,
      canonicalRequestStr: canonical,
    );

    final signingKey = deriveSigningKey(
      secretAccessKey: secretAccessKey,
      dateStamp: dateStamp,
      region: region,
      service: service,
    );
    final signature = hexEncode(hmacSha256(signingKey, utf8.encode(sts)));

    final signedHeaderNames = (headers.keys.toList()..sort()).join(';');
    headers['authorization'] =
        'AWS4-HMAC-SHA256 '
        'Credential=$accessKeyId/$credentialScope,'
        'SignedHeaders=$signedHeaderNames,'
        'Signature=$signature';
    return headers;
  }
}
