import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/sigv4_signer.dart';

/// Listing entry returned by [S3ApiClient.listObjects].
class S3ObjectInfo {
  final String key;
  final DateTime lastModified;
  final int? size;

  const S3ObjectInfo({
    required this.key,
    required this.lastModified,
    this.size,
  });
}

/// One uploaded part of a multipart session, as needed for completion
/// and resume validation.
class S3PartInfo {
  final int partNumber;
  final String etag;

  const S3PartInfo({required this.partNumber, required this.etag});
}

/// One in-progress multipart upload session, as listed for stale-session
/// reaping (orphan-prevention spec 6.1).
class S3MultipartUploadInfo {
  final String key; // wire key (includes any configured prefix)
  final String uploadId;
  final DateTime initiated;

  const S3MultipartUploadInfo({
    required this.key,
    required this.uploadId,
    required this.initiated,
  });
}

/// Minimal S3 REST client: the five operations the sync backend needs,
/// signed with SigV4. Throws [CloudStorageException] for every failure so
/// callers never see raw HTTP details. The secret key and Authorization
/// header are never logged or embedded in error messages.
class S3ApiClient {
  S3ApiClient(
    S3Config config, {
    http.Client? httpClient,
    DateTime Function()? now,
    Duration retryDelay = const Duration(milliseconds: 500),
    int maxAttempts = defaultMaxAttempts,
    Duration maxRetryDelay = defaultMaxRetryDelay,
    Duration responseTimeout = defaultResponseTimeout,
    Duration uploadTimeout = defaultUploadTimeout,
    Duration idleTimeout = defaultIdleTimeout,
    Random? random,
    this.onRegionCorrected,
  }) : assert(maxAttempts >= 1, 'a request must be attempted at least once'),
       assert(
         !retryDelay.isNegative && !maxRetryDelay.isNegative,
         'a negative backoff reaches Random.nextInt with a non-positive max '
         'and throws RangeError',
       ),
       _config = config,
       _region = config.region,
       _http = httpClient ?? _defaultClient(),
       _now = now ?? DateTime.now,
       _retryDelay = retryDelay,
       _maxAttempts = maxAttempts,
       _maxRetryDelay = maxRetryDelay,
       _responseTimeout = responseTimeout,
       _uploadTimeout = uploadTimeout,
       _idleTimeout = idleTimeout,
       _random = random ?? Random();

  /// The client used when the caller injects none.
  ///
  /// A bare `http.Client()` leaves `HttpClient.connectionTimeout` null, so a
  /// TCP connect to an unreachable endpoint waits on the OS default -- minutes
  /// on some Windows configurations. The deadlines in [_send] bound a socket
  /// that connects and then stalls; this bounds one that never connects.
  static http.Client _defaultClient() =>
      IOClient(HttpClient()..connectionTimeout = defaultConnectTimeout);

  /// Attempts per request, including the first.
  ///
  /// A base publish is 15+ sequential multi-megabyte PUTs (8 MiB parts), and
  /// the manifest that commits them is written last, so a single failed part
  /// aborts the whole sync and the next one re-uploads the base from part 0.
  /// Two attempts 500ms apart are the same network moment on a mobile radio,
  /// which made whole-publish success p^N and left large first syncs failing
  /// nine times in ten (#942).
  ///
  /// Six attempts with the delays below span 7.75-15.5s of waiting, which is
  /// the timescale a handover or a brief loss of signal resolves on. It does
  /// not delay a genuinely offline device by that much per request: the sync
  /// aborts at the FIRST request to exhaust its budget, so being offline costs
  /// one budget, not one per part.
  static const int defaultMaxAttempts = 6;

  /// Ceiling for one backoff wait, so the exponential cannot run away on a
  /// request that is retried to exhaustion.
  static const Duration defaultMaxRetryDelay = Duration(seconds: 16);

  /// How long to wait for the TCP connection itself.
  static const Duration defaultConnectTimeout = Duration(seconds: 15);

  /// How long to wait for a response's status and headers on a request with
  /// no body. Covers TLS setup and the server's own think time.
  static const Duration defaultResponseTimeout = Duration(seconds: 30);

  /// The same deadline for a request that CARRIES a body.
  ///
  /// Separate and far more generous, because `Client.send` does not complete
  /// until the body has been written: for a PUT the "wait for a response"
  /// window contains the whole upload. A multipart part is 8 MiB, which at
  /// 110 kbps takes ten minutes, and killing a part that was making progress
  /// is exactly the failure mode that left large first syncs failing nine
  /// times in ten (#942). Ten minutes still bounds a socket that has genuinely
  /// wedged, which is all this needs to do.
  static const Duration defaultUploadTimeout = Duration(minutes: 10);

  /// How long a response body may go without delivering a single byte.
  ///
  /// Deliberately an IDLE gap rather than a total budget: a legitimate 8 MiB
  /// download over a weak mobile link takes minutes and must not be killed,
  /// while a connection that has stopped delivering is dead regardless of how
  /// little it had left to send.
  static const Duration defaultIdleTimeout = Duration(seconds: 30);

  final S3Config _config;
  final http.Client _http;
  final DateTime Function() _now;
  final Duration _retryDelay;
  final int _maxAttempts;
  final Duration _maxRetryDelay;
  final Duration _responseTimeout;
  final Duration _uploadTimeout;
  final Duration _idleTimeout;
  final Random _random;

  /// Called after a server region hint led to a successful replay, so the
  /// owner can persist the corrected region.
  final void Function(String region)? onRegionCorrected;

  /// Effective signing/addressing region: starts as the configured region
  /// and is updated for the client's lifetime when the server corrects it.
  String _region;

  Future<void> putObject(
    String key,
    Uint8List bytes, {
    String? contentType,
  }) async {
    final response = await _sendWithRetry(
      'PUT',
      key,
      body: bytes,
      extraHeaders: contentType == null
          ? const {}
          : {'content-type': contentType},
    );
    if (response.statusCode != 200) _throwFor('upload', key, response);
  }

  Future<Uint8List> getObject(String key) async {
    final response = await _sendWithRetry('GET', key);
    if (response.statusCode == 200) return response.bodyBytes;
    if (response.statusCode == 404) {
      throw CloudStorageException('File not found in S3: $key');
    }
    _throwFor('download', key, response);
  }

  Future<S3ObjectInfo?> headObject(String key) async {
    final response = await _sendWithRetry('HEAD', key);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throwFor('inspect', key, response);
    final lastModifiedHeader = response.headers['last-modified'];
    final contentLength = response.headers['content-length'];
    DateTime lastModified;
    if (lastModifiedHeader != null) {
      try {
        lastModified = HttpDate.parse(lastModifiedHeader);
      } on HttpException {
        lastModified = _now().toUtc();
      }
    } else {
      lastModified = _now().toUtc();
    }
    return S3ObjectInfo(
      key: key,
      lastModified: lastModified,
      size: contentLength != null ? int.tryParse(contentLength) : null,
    );
  }

  Future<void> deleteObject(String key) async {
    final response = await _sendWithRetry('DELETE', key);
    // 404 is success for an idempotent delete; S3 itself returns 204 even
    // for keys that never existed, but some compatible servers 404.
    const okStatuses = {200, 204, 404};
    if (!okStatuses.contains(response.statusCode)) {
      _throwFor('delete', key, response);
    }
  }

  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    final results = <S3ObjectInfo>[];
    String? continuationToken;
    do {
      final response = await _sendWithRetry(
        'GET',
        '',
        queryParams: {
          'list-type': '2',
          if (prefix.isNotEmpty) 'prefix': prefix,
          'continuation-token': ?continuationToken,
          if (maxKeys != null) 'max-keys': '$maxKeys',
        },
      );
      if (response.statusCode != 200) _throwFor('list', prefix, response);

      final (pageObjects, nextToken) = _parseListPage(response.bodyBytes);
      results.addAll(pageObjects);
      continuationToken = maxKeys != null ? null : nextToken;
    } while (continuationToken != null);
    return results;
  }

  /// Lists in-progress multipart upload sessions (parts uploaded but the
  /// session neither completed nor aborted). Invisible to [listObjects] -
  /// stranded sessions bill storage until aborted, and raw buckets have no
  /// default expiry lifecycle rule (orphan-prevention spec 6.1).
  Future<List<S3MultipartUploadInfo>> listMultipartUploads({
    String prefix = '',
  }) async {
    final results = <S3MultipartUploadInfo>[];
    String? keyMarker;
    String? uploadIdMarker;
    do {
      final response = await _sendWithRetry(
        'GET',
        '',
        queryParams: {
          'uploads': '',
          if (prefix.isNotEmpty) 'prefix': prefix,
          'key-marker': ?keyMarker,
          'upload-id-marker': ?uploadIdMarker,
        },
      );
      if (response.statusCode != 200) {
        _throwFor('list-uploads', prefix, response);
      }
      try {
        final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
        for (final upload in document.findAllElements('Upload')) {
          final key = upload.getElement('Key')?.innerText;
          final uploadId = upload.getElement('UploadId')?.innerText;
          final initiated = upload.getElement('Initiated')?.innerText;
          if (key == null || uploadId == null || initiated == null) continue;
          results.add(
            S3MultipartUploadInfo(
              key: key,
              uploadId: uploadId,
              initiated: DateTime.parse(initiated),
            ),
          );
        }
        final truncated =
            document.findAllElements('IsTruncated').firstOrNull?.innerText ==
            'true';
        keyMarker = truncated
            ? document.findAllElements('NextKeyMarker').firstOrNull?.innerText
            : null;
        uploadIdMarker = truncated
            ? document
                  .findAllElements('NextUploadIdMarker')
                  .firstOrNull
                  ?.innerText
            : null;
        if (truncated && keyMarker == null && uploadIdMarker == null) break;
      } on FormatException catch (e) {
        throw CloudStorageException(
          'S3 returned an unreadable multipart-uploads list',
          e,
        );
      }
    } while (keyMarker != null || uploadIdMarker != null);
    return results;
  }

  /// Parses a single ListBucketResult XML page.
  ///
  /// Returns the objects found and the next continuation token (null if done).
  /// Wraps any [FormatException] (including [XmlParserException]) in a
  /// [CloudStorageException].
  (List<S3ObjectInfo>, String?) _parseListPage(Uint8List bodyBytes) {
    try {
      final document = XmlDocument.parse(utf8.decode(bodyBytes));
      final pageObjects = <S3ObjectInfo>[];
      for (final contents in document.findAllElements('Contents')) {
        final key = contents.getElement('Key')?.innerText;
        final lastModified = contents.getElement('LastModified')?.innerText;
        if (key == null || lastModified == null) continue;
        pageObjects.add(
          S3ObjectInfo(
            key: key,
            lastModified: DateTime.parse(lastModified),
            size: int.tryParse(contents.getElement('Size')?.innerText ?? ''),
          ),
        );
      }
      final truncated =
          document.findAllElements('IsTruncated').firstOrNull?.innerText ==
          'true';
      final nextToken = truncated
          ? document
                .findAllElements('NextContinuationToken')
                .firstOrNull
                ?.innerText
          : null;
      return (pageObjects, nextToken);
    } on FormatException catch (e) {
      throw CloudStorageException('S3 returned an unreadable list response', e);
    }
  }

  /// Starts a multipart upload session; returns the server's uploadId.
  Future<String> createMultipartUpload(
    String key, {
    required String contentType,
  }) async {
    final response = await _sendWithRetry(
      'POST',
      key,
      queryParams: {'uploads': ''},
      extraHeaders: {'content-type': contentType},
    );
    if (response.statusCode != 200) _throwFor('start upload', key, response);
    final uploadId = _xmlElementText(response.body, 'UploadId');
    if (uploadId == null || uploadId.isEmpty) {
      throw CloudStorageException('S3 returned no UploadId for "$key"');
    }
    return uploadId;
  }

  /// Uploads one part; returns its ETag for the completion manifest.
  Future<String> uploadPart(
    String key, {
    required String uploadId,
    required int partNumber,
    required Uint8List bytes,
  }) async {
    final response = await _sendWithRetry(
      'PUT',
      key,
      queryParams: {'partNumber': '$partNumber', 'uploadId': uploadId},
      body: bytes,
    );
    if (response.statusCode != 200) {
      _throwFor('upload part $partNumber of', key, response);
    }
    final etag = response.headers['etag'];
    if (etag == null || etag.isEmpty) {
      throw CloudStorageException(
        'S3 returned no ETag for part $partNumber of "$key"',
      );
    }
    return etag;
  }

  Future<void> completeMultipartUpload(
    String key, {
    required String uploadId,
    required List<S3PartInfo> parts,
  }) async {
    final manifest = StringBuffer('<CompleteMultipartUpload>');
    for (final part in parts) {
      manifest.write(
        '<Part><PartNumber>${part.partNumber}</PartNumber>'
        '<ETag>${part.etag}</ETag></Part>',
      );
    }
    manifest.write('</CompleteMultipartUpload>');
    final response = await _sendWithRetry(
      'POST',
      key,
      queryParams: {'uploadId': uploadId},
      body: Uint8List.fromList(utf8.encode(manifest.toString())),
    );
    if (response.statusCode != 200) _throwFor('finish upload', key, response);
    // S3 reports completion errors inside a 200 body.
    if (_xmlElementText(response.body, 'Code') != null) {
      throw CloudStorageException(
        'S3 rejected the upload completion for "$key"',
      );
    }
  }

  /// Idempotent: aborting an unknown session succeeds.
  Future<void> abortMultipartUpload(
    String key, {
    required String uploadId,
  }) async {
    final response = await _sendWithRetry(
      'DELETE',
      key,
      queryParams: {'uploadId': uploadId},
    );
    const okStatuses = {200, 204, 404};
    if (!okStatuses.contains(response.statusCode)) {
      _throwFor('abort upload', key, response);
    }
  }

  Future<List<S3PartInfo>> listParts(
    String key, {
    required String uploadId,
  }) async {
    final response = await _sendWithRetry(
      'GET',
      key,
      queryParams: {'uploadId': uploadId},
    );
    if (response.statusCode != 200) _throwFor('list parts of', key, response);
    try {
      final document = XmlDocument.parse(response.body);
      return document
          .findAllElements('Part')
          .map(
            (part) => S3PartInfo(
              partNumber: int.parse(part.getElement('PartNumber')!.innerText),
              etag: part.getElement('ETag')!.innerText,
            ),
          )
          .toList();
    } on Exception catch (e) {
      throw CloudStorageException('S3 returned an unreadable part list', e);
    }
  }

  /// Byte-range read: [start]..[endInclusive]. Returns the slice and the
  /// object's total length parsed from Content-Range.
  Future<({Uint8List bytes, int totalLength})> getObjectRange(
    String key, {
    required int start,
    required int endInclusive,
  }) async {
    final response = await _sendWithRetry(
      'GET',
      key,
      extraHeaders: {'range': 'bytes=$start-$endInclusive'},
    );
    if (response.statusCode == 404) {
      throw CloudStorageException('File not found in S3: $key');
    }
    if (response.statusCode != 206 && response.statusCode != 200) {
      _throwFor('download range of', key, response);
    }
    final contentRange = response.headers['content-range'];
    final total = contentRange == null
        ? response.bodyBytes.length
        : int.parse(contentRange.split('/').last);
    return (bytes: response.bodyBytes, totalLength: total);
  }

  /// Closes the underlying HTTP client (including an injected one).
  void close() => _http.close();

  /// Scheme/host/port/path for [key], honoring path-style vs virtual-hosted
  /// addressing. The path comes back already SigV4-encoded so the signed
  /// bytes and the wire bytes cannot diverge.
  ({String scheme, String host, int? port, String path}) _target(String key) {
    // effectivePathStyle, not the raw flag: a dotted bucket over HTTPS is
    // forced path-style to dodge the wildcard-cert TLS failure (issue #335).
    final pathStyle = _config.effectivePathStyle;
    final String scheme;
    final String host;
    int? port;
    if (_config.isAws) {
      scheme = 'https';
      host = pathStyle
          ? 's3.$_region.amazonaws.com'
          : '${_config.bucket}.s3.$_region.amazonaws.com';
    } else {
      final endpointUri = Uri.parse(_config.endpoint);
      final endpointHost = _effectiveCustomHost(endpointUri.host);
      scheme = endpointUri.scheme;
      host = pathStyle ? endpointHost : '${_config.bucket}.$endpointHost';
      if (endpointUri.hasPort) port = endpointUri.port;
    }
    final encodedKey = SigV4Signer.uriEncode(key, encodeSlash: false);
    final path = pathStyle
        ? '/${_config.bucket}${encodedKey.isEmpty ? '/' : '/$encodedKey'}'
        : '/$encodedKey';
    return (scheme: scheme, host: host, port: port, path: path);
  }

  /// Sends [method] with up to [_maxAttempts] attempts, backing off between
  /// them. Retries transport failures and retryable statuses (5xx, 429);
  /// every other status is returned to the caller, which decides what it
  /// means. A request that exhausts the budget on transport failures throws
  /// [CloudStorageException]; one that exhausts it on a retryable status
  /// returns that last response, so the caller still reports the real HTTP
  /// code rather than a generic reachability message.
  ///
  /// Every operation routed through here is safe to repeat: the object writes
  /// are idempotent by key, and the two multipart POSTs were already retried
  /// before this budget existed (a duplicated session is reaped by the
  /// stale-session sweep, orphan-prevention spec 6.1).
  Future<http.Response> _sendWithRetry(
    String method,
    String key, {
    Map<String, String> queryParams = const {},
    Uint8List? body,
    Map<String, String> extraHeaders = const {},
  }) async {
    Object? transportError;
    for (var attempt = 1; ; attempt++) {
      final lastAttempt = attempt >= _maxAttempts;
      try {
        var response = await _send(
          method,
          key,
          queryParams: queryParams,
          body: body,
          extraHeaders: extraHeaders,
        );
        if (response.statusCode >= 300) {
          final corrected = await _replayWithRegionHint(
            response,
            method,
            key,
            queryParams,
            body,
            extraHeaders,
          );
          // The replay flows through the retry decision below, whose next
          // attempt signs with the corrected region.
          if (corrected != null) response = corrected;
        }
        if (lastAttempt || !_isRetryableStatus(response.statusCode)) {
          return response;
        }
      } on FormatException catch (e) {
        // A malformed endpoint is a configuration fault: retrying it can only
        // fail the same way.
        throw CloudStorageException(
          'Invalid S3 endpoint configuration: ${_config.endpoint}',
          e,
        );
      } on http.ClientException catch (e) {
        transportError = e;
      } on IOException catch (e) {
        // Socket or TLS failure.
        transportError = e;
      } on TimeoutException catch (e) {
        transportError = e;
      }
      if (lastAttempt) {
        throw CloudStorageException(
          'Could not reach S3 endpoint ${_config.displayHost}',
          transportError,
        );
      }
      await Future<void>.delayed(_backoffFor(attempt));
    }
  }

  /// 5xx is a server-side fault worth repeating; 429 is the throttle signal
  /// used by R2/B2/MinIO where AWS sends 503 SlowDown. Everything else -
  /// including 403, 404 and the region-hint 301/400 handled above - is a
  /// verdict about the request itself, and repeating it just burns time.
  static bool _isRetryableStatus(int statusCode) =>
      statusCode >= 500 || statusCode == 429;

  /// Wait before the attempt after [attempt] (1-based): equal jitter, i.e. a
  /// uniform pick from `[ceiling / 2, ceiling]`.
  ///
  /// The jitter decorrelates devices that hit the same throttled bucket prefix
  /// at once, which lockstep backoff keeps colliding. The half-ceiling floor
  /// is what full jitter would give up: the point of backing off here is to
  /// outlast a dropout, and a run of near-zero waits would spend the whole
  /// budget inside it.
  Duration _backoffFor(int attempt) {
    final ceiling = backoffCeilingFor(_retryDelay, attempt, _maxRetryDelay);
    if (ceiling == Duration.zero) return Duration.zero;
    final half = ceiling.inMicroseconds ~/ 2;
    return Duration(microseconds: half + _random.nextInt(half + 1));
  }

  /// Un-jittered `base * 2^(attempt-1)`, capped at [cap]. Exposed so the
  /// growth curve is testable without the jitter.
  @visibleForTesting
  static Duration backoffCeilingFor(Duration base, int attempt, Duration cap) {
    if (base == Duration.zero) return Duration.zero;
    // Shift the exponent, not the duration: a large attempt would otherwise
    // overflow the microsecond product before the cap could clamp it.
    final exponent = attempt - 1;
    if (exponent >= 32) return cap;
    final scaled = base * (1 << exponent);
    return scaled > cap ? cap : scaled;
  }

  /// If [response] carries a region hint that differs from the effective
  /// region, adopts it, replays the request once, and reports the
  /// correction when the replay succeeds. Returns null when no correction
  /// applies. A transport exception from the replay propagates to
  /// _sendWithRetry's catch clauses, whose retry then signs with the
  /// already-corrected region.
  Future<http.Response?> _replayWithRegionHint(
    http.Response response,
    String method,
    String key,
    Map<String, String> queryParams,
    Uint8List? body,
    Map<String, String> extraHeaders,
  ) async {
    final hint = _regionHint(response);
    if (hint == null || hint == _region) return null;
    _region = hint;
    final replay = await _send(
      method,
      key,
      queryParams: queryParams,
      body: body,
      extraHeaders: extraHeaders,
    );
    if (replay.statusCode < 300) onRegionCorrected?.call(hint);
    return replay;
  }

  /// AWS regional hosts are region-templated: a regional endpoint never
  /// serves another region's buckets, so when a server hint moves the
  /// effective region the request must move to the matching regional host.
  /// Every other custom endpoint (and the global s3.amazonaws.com, which
  /// routes cross-region via DNS) is opaque and passes through unchanged.
  String _effectiveCustomHost(String endpointHost) {
    final match = _awsRegionalHostPattern.firstMatch(
      endpointHost.toLowerCase(),
    );
    if (match == null || match.group(2) == _region) return endpointHost;
    // Preserve the dualstack variant: rebuilding to a plain host would
    // silently regress IPv6/dualstack connectivity after a correction.
    final dualstack = match.group(1) ?? '';
    return 's3.$dualstack$_region.amazonaws.com';
  }

  static final _awsRegionalHostPattern = RegExp(
    r'^s3[.-](dualstack\.)?([a-z0-9-]+)\.amazonaws\.com$',
  );

  /// The region the server says it expects: the x-amz-bucket-region
  /// header (301 and most 403 responses), or the Region element of an
  /// AuthorizationHeaderMalformed error body.
  String? _regionHint(http.Response response) {
    final header = response.headers['x-amz-bucket-region'];
    if (header != null && header.isNotEmpty) return header;
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_xmlElementText(body, 'Code') != 'AuthorizationHeaderMalformed') {
      return null;
    }
    final region = _xmlElementText(body, 'Region');
    return (region == null || region.isEmpty) ? null : region;
  }

  Future<http.Response> _send(
    String method,
    String key, {
    Map<String, String> queryParams = const {},
    Uint8List? body,
    Map<String, String> extraHeaders = const {},
  }) async {
    final target = _target(key);
    final authority = target.port == null
        ? target.host
        : '${target.host}:${target.port}';
    final canonicalQuery = SigV4Signer.canonicalQueryString(queryParams);
    final uri = Uri.parse(
      '${target.scheme}://$authority${target.path}'
      '${canonicalQuery.isEmpty ? '' : '?$canonicalQuery'}',
    );

    final payload = body ?? Uint8List(0);
    final headers = SigV4Signer.sign(
      method: method,
      host: authority,
      canonicalUri: target.path,
      queryParams: queryParams,
      payload: payload,
      accessKeyId: _config.accessKeyId,
      secretAccessKey: _config.secretAccessKey,
      region: _region,
      requestTime: _now(),
    );
    // The http client derives Host from the URL; it must not be set manually.
    headers.remove('host');

    final request = http.Request(method, uri)..headers.addAll(headers);
    // Unsigned extras (e.g. Range): only signed headers participate in the
    // SigV4 signature, so S3 accepts these alongside it.
    request.headers.addAll(extraHeaders);
    if (body != null) request.bodyBytes = body;

    // Two deadlines rather than one. Without them a stalled socket parks the
    // request forever, and since nothing caps concurrency on the media store's
    // read path, a gallery opens one such request per visible tile (#1175).
    // _sendWithRetry already classifies TimeoutException as a retryable
    // transport fault, so both surface as an ordinary retry and then, at
    // budget exhaustion, as a CloudStorageException.
    final hasBody = body != null && body.isNotEmpty;
    final streamed = await _http
        .send(request)
        .timeout(hasBody ? _uploadTimeout : _responseTimeout);
    final bytes = await http.ByteStream(
      streamed.stream.timeout(_idleTimeout),
    ).toBytes();
    return http.Response.bytes(
      bytes,
      streamed.statusCode,
      request: streamed.request,
      headers: streamed.headers,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  Never _throwFor(String operation, String key, http.Response response) {
    final errorCode = _xmlElementText(
      utf8.decode(response.bodyBytes, allowMalformed: true),
      'Code',
    );
    // Matched by error code regardless of HTTP status: AWS uses 400, some
    // compatible servers 403.
    if (errorCode == 'AuthorizationHeaderMalformed') {
      throw const CloudStorageException(
        "S3 rejected the request's signature region. Open Advanced and "
        'set Region to the value your provider expects.',
      );
    }
    if (response.statusCode == 403) {
      if (errorCode == 'RequestTimeTooSkewed') {
        throw const CloudStorageException(
          'S3 rejected the request time. The device clock is more than '
          '15 minutes off; correct the system time and try again.',
        );
      }
      throw const CloudStorageException(
        'Access denied. Check the access key, secret key, and bucket '
        'permissions.',
      );
    }
    if (response.statusCode == 404 && errorCode == 'NoSuchBucket') {
      throw CloudStorageException('Bucket "${_config.bucket}" not found');
    }
    throw CloudStorageException(
      'S3 $operation failed for "$key" (HTTP ${response.statusCode})',
    );
  }

  String? _xmlElementText(String body, String element) {
    if (body.isEmpty) return null;
    try {
      return XmlDocument.parse(
        body,
      ).findAllElements(element).firstOrNull?.innerText;
    } on XmlException {
      return null;
    }
  }
}
