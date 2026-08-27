import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/atom_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/csv_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/json_manifest_parser.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_format_sniffer.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Minimal interface expected from 3a's `NetworkCredentialsService`. We only
/// need per-host headers; full credential management lives in 3a.
///
/// Task 13 will provide a thin adapter that wraps the real
/// `NetworkCredentialsService.headersFor(...)` (which returns a nullable
/// map) so 3b stays loosely coupled to 3a's exact signatures.
abstract class ManifestCredentialsLookup {
  Future<Map<String, String>> headersFor(Uri uri);
}

/// Outcome of a manifest fetch — a tagged union of success / not-modified /
/// failure. Callers (the upcoming `ManifestSubscriptionRepository` poll
/// loop in Task 8 and the import preview UI in Phase 3c) pattern-match on
/// the runtime type to drive their next step.
sealed class ManifestFetchOutcome {
  const ManifestFetchOutcome();
}

/// HTTP 200 with a body that successfully sniffed and parsed. The
/// `etag` and `lastModified` are echoed back so the subscription poller
/// can persist them for the next conditional-GET round.
class ManifestFetchSuccess extends ManifestFetchOutcome {
  const ManifestFetchSuccess({
    required this.parsed,
    this.etag,
    this.lastModified,
  });

  final ManifestParseResult parsed;
  final String? etag;
  final String? lastModified;
}

/// HTTP 304 — caller's `If-None-Match` / `If-Modified-Since` matched.
/// No body to parse; poller bumps `nextPollAt` and moves on.
class ManifestFetchNotModified extends ManifestFetchOutcome {
  const ManifestFetchNotModified();
}

/// Any other terminal outcome: 4xx (including 401), 5xx, network error,
/// sniff failure, or parser `FormatException`. The `unauthorized` getter
/// is a convenience for the Settings page to prompt for re-auth.
class ManifestFetchFailure extends ManifestFetchOutcome {
  const ManifestFetchFailure({this.statusCode, required this.message});

  final int? statusCode;
  final String message;

  bool get unauthorized => statusCode == 401;
}

/// Bridge between HTTP and the three manifest parsers (JSON / Atom / CSV).
///
/// Steps:
/// 1. Build headers (per-host auth from [credentials] + optional
///    conditional `If-None-Match` / `If-Modified-Since`).
/// 2. GET the URL via the injected [http.Client] (real or `MockClient`).
/// 3. Branch on status code:
///    - 304 -> [ManifestFetchNotModified].
///    - non-2xx -> [ManifestFetchFailure] (including 401 -> `unauthorized`).
///    - 2xx -> sniff the format (or honor [formatOverride]) and dispatch
///      to the matching parser, returning [ManifestFetchSuccess] with the
///      response's `ETag` and `Last-Modified` echoed back.
class ManifestFetchService {
  ManifestFetchService({
    required http.Client client,
    required this.credentials,
    ManifestFormatSniffer? sniffer,
  }) : _client = client,
       _sniffer = sniffer ?? ManifestFormatSniffer();

  final http.Client _client;
  final ManifestCredentialsLookup credentials;
  final ManifestFormatSniffer _sniffer;
  final _log = LoggerService.forClass(ManifestFetchService);

  Future<ManifestFetchOutcome> fetch(
    Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async {
    try {
      final headers = <String, String>{
        ...await credentials.headersFor(url),
        'If-None-Match': ?ifNoneMatch,
        'If-Modified-Since': ?ifModifiedSince,
      };
      final resp = await _client.get(url, headers: headers);
      if (resp.statusCode == 304) {
        return const ManifestFetchNotModified();
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return ManifestFetchFailure(
          statusCode: resp.statusCode,
          message: 'HTTP ${resp.statusCode}',
        );
      }
      final body = resp.body;
      final ManifestFormat format;
      try {
        format =
            formatOverride ??
            _sniffer.sniff(
              contentType: resp.headers['content-type'],
              body: body,
            );
      } on FormatException catch (e) {
        return ManifestFetchFailure(message: e.message);
      }
      try {
        final parsed = _parse(format, body);
        return ManifestFetchSuccess(
          parsed: parsed,
          etag: resp.headers['etag'],
          lastModified: resp.headers['last-modified'],
        );
      } on FormatException catch (e) {
        return ManifestFetchFailure(message: e.message);
      }
    } catch (e, st) {
      _log.error('Manifest fetch failed: $url', error: e, stackTrace: st);
      return ManifestFetchFailure(message: '$e');
    }
  }

  ManifestParseResult _parse(ManifestFormat format, String body) {
    switch (format) {
      case ManifestFormat.json:
        return JsonManifestParser().parse(body);
      case ManifestFormat.atom:
        return AtomManifestParser().parse(body);
      case ManifestFormat.csv:
        return CsvManifestParser().parse(body);
    }
  }
}
