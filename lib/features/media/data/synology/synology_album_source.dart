import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/synology/synology_api.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/data/synology/synology_share_sessions.dart';

/// Failure message when no password is stored for a share yet, as opposed to
/// a stored password the share rejected.
const String kSynologyPasswordMissingMessage = 'This share needs its password';

/// The failure message when the share refused the saved password.
const String kSynologyPasswordRejectedMessage =
    'The share did not accept the password';

/// Whether a fetch failure [message] means the share wants a (different)
/// password, which the user can fix by typing one.
bool synologyNeedsPassword(String? message) =>
    message == kSynologyPasswordMissingMessage ||
    message == kSynologyPasswordRejectedMessage;

/// Reads a shared Synology Photos album as if it were a manifest feed, so the
/// subscription poller and the manifest panel need no Synology branch.
///
/// Only photos are read in this prototype; videos and live photos are
/// skipped. See
/// `docs/design/specs/2026-11-21-synology-photos-shared-album-design.md`.
class SynologyAlbumSource {
  SynologyAlbumSource({
    required http.Client client,
    required SynologyShareSessions sessions,
    required Future<String?> Function(SynologyShareLink link) passwordFor,
    this.pageSize = 1000,
    this.maxPages = 100,
  }) : _client = client,
       _sessions = sessions,
       _passwordFor = passwordFor;

  final http.Client _client;
  final SynologyShareSessions _sessions;
  final Future<String?> Function(SynologyShareLink link) _passwordFor;

  /// Items requested per listing call.
  final int pageSize;

  /// Upper bound on listing calls, so a server that never returns a short
  /// page cannot keep the poller busy forever.
  final int maxPages;

  final _log = LoggerService.forClass(SynologyAlbumSource);

  /// Reads every photo of [link]'s album.
  ///
  /// Never returns a partial list: any failing page fails the whole fetch,
  /// because the poller reads a missing entry as "removed from the feed" and
  /// flags its row orphaned on every device.
  Future<ManifestFetchOutcome> fetch(SynologyShareLink link) async {
    final String? password;
    try {
      password = await _passwordFor(link);
    } catch (e) {
      return ManifestFetchFailure(message: 'Could not read the password: $e');
    }
    // A share without a password logs in with an empty one. Without a saved
    // password that is tried first; refused, the share needs its password.
    final saved = password != null && password.isNotEmpty;
    final effective = saved ? password : '';
    try {
      try {
        return await _read(link, effective);
      } on _SessionLost catch (lost) {
        // Another login (another device, or the web page) replaced the
        // session. One fresh login; a second loss is a real failure.
        _sessions.invalidate(link, lost.sid);
        return await _read(link, effective);
      }
    } on _SessionLost {
      return const ManifestFetchFailure(
        message: 'The share keeps rejecting the session',
      );
    } on SynologyShareException catch (e) {
      if (e.kind == SynologyShareErrorKind.wrongPassword) {
        return ManifestFetchFailure(
          statusCode: 401,
          message: saved
              ? kSynologyPasswordRejectedMessage
              : kSynologyPasswordMissingMessage,
        );
      }
      return ManifestFetchFailure(message: e.message);
    } catch (e, st) {
      _log.error('Reading the shared album failed', error: e, stackTrace: st);
      return ManifestFetchFailure(message: '$e');
    }
  }

  Future<ManifestFetchSuccess> _read(
    SynologyShareLink link,
    String password,
  ) async {
    final sid = await _sessions.sessionFor(link, password);
    final album = await _call(link, sid, {
      'api': 'SYNO.Foto.Browse.Album',
      'method': 'get',
      'version': '1',
      'passphrase': link.code,
      'additional': '["sharing_info"]',
    });
    final albumInfo = _firstOf(album['list']);
    final title = albumInfo?['name'] is String
        ? albumInfo!['name'] as String
        : null;
    final downloadsAllowed = _downloadsAllowed(albumInfo);

    final items = <Object?>[];
    for (var page = 0; page < maxPages; page++) {
      final data = await _call(link, sid, {
        'api': 'SYNO.Foto.Browse.Item',
        'method': 'list',
        'version': '1',
        'offset': '${page * pageSize}',
        'limit': '$pageSize',
        'passphrase': link.code,
        'additional': '["thumbnail","resolution"]',
      });
      final list = data['list'];
      if (list is! List<Object?>) {
        throw const SynologyShareException(
          SynologyShareErrorKind.unexpected,
          'The share sent no item list',
        );
      }
      items.addAll(list);
      if (list.length < pageSize) break;
      if (page == maxPages - 1) {
        throw const SynologyShareException(
          SynologyShareErrorKind.unexpected,
          'The album is larger than this client reads',
        );
      }
    }

    final mapped = synologyEntriesFrom(
      items,
      link: link,
      downloadsAllowed: downloadsAllowed,
    );
    final problem = synologyFormatProblem(items, mapped);
    if (problem != null) {
      _log.warning('Synology album not read: $problem');
      throw SynologyShareException(SynologyShareErrorKind.unexpected, problem);
    }
    return ManifestFetchSuccess(
      parsed: ManifestParseResult(
        // No dedicated format yet: a Synology subscription is recognised by
        // its URL, and the stored format stays `json` (design, section 3).
        format: ManifestFormat.json,
        title: title,
        entries: mapped.entries,
        warnings: mapped.warnings,
      ),
    );
  }

  /// One authenticated API call. Throws [_SessionLost] when the share no
  /// longer accepts [sid], and [SynologyShareException] for anything else.
  Future<Map<String, Object?>> _call(
    SynologyShareLink link,
    String sid,
    Map<String, String> form,
  ) async {
    final http.Response response;
    try {
      response = await _client.post(
        link.apiUri,
        headers: SynologyShareSessions.sessionHeaders(link, sid),
        body: form,
      );
    } catch (e) {
      throw SynologyShareException(
        SynologyShareErrorKind.unreachable,
        'Could not reach the share: $e',
      );
    }
    try {
      return decodeSynologyEnvelope(response);
    } on SynologyShareException catch (e) {
      if (e.kind == SynologyShareErrorKind.noSession) throw _SessionLost(sid);
      rethrow;
    }
  }

  static Map<String, Object?>? _firstOf(Object? list) {
    if (list is! List<Object?> || list.isEmpty) return null;
    final first = list.first;
    return first is Map<String, Object?> ? first : null;
  }

  /// Whether the share serves originals. Unknown counts as allowed: a share
  /// that does not say is left to fail per item rather than downgraded.
  static bool _downloadsAllowed(Map<String, Object?>? album) {
    final additional = album?['additional'];
    if (additional is! Map<String, Object?>) return true;
    final sharing = additional['sharing_info'];
    if (sharing is! Map<String, Object?>) return true;
    return sharing['privacy_type'] != 'public-view';
  }
}

/// Entries mapped from a share's item list, plus a warning per item skipped
/// because it was malformed. Videos and live photos are skipped silently.
typedef SynologyMappedEntries = ({
  List<ManifestEntry> entries,
  List<String> warnings,
});

/// Why [items] look like a list this client no longer understands, or null
/// when they read normally.
///
/// A changed API must fail the fetch, never pass as a smaller album: the
/// poller reads every entry missing from a successful fetch as removed and
/// marks its row missing on every device. So a list whose items carry no
/// type this client knows, or whose photos mostly fail to parse, is a
/// failure. A few unreadable photos are not: those are skipped with a
/// warning, as before.
String? synologyFormatProblem(
  List<Object?> items,
  SynologyMappedEntries mapped,
) {
  if (items.isEmpty) return null;
  const knownTypes = {'photo', 'video', 'live'};
  final objects = items.whereType<Map<String, Object?>>().toList();
  final typed = objects.where((i) => knownTypes.contains(i['type'])).length;
  if (typed == 0) {
    final seen = {for (final i in objects) '${i['type']}'}.take(5).join(', ');
    return 'Album format not recognised: none of ${items.length} items has a '
        'known type (seen: ${seen.isEmpty ? 'no objects' : seen})';
  }
  final photos = objects.where((i) => i['type'] == 'photo').length;
  if (photos > 0 && mapped.entries.length * 2 < photos) {
    final first = mapped.warnings.isEmpty
        ? ''
        : ' First: ${mapped.warnings.first}';
    return 'Album format not recognised: only ${mapped.entries.length} of '
        '$photos photos could be read.$first';
  }
  return null;
}

/// Maps Synology item maps to manifest entries.
///
/// `entryKey` is built from capture time and file size, not the Synology id:
/// a move through File Station or SMB can be re-indexed as a new item with a
/// new id, and keying on the id would orphan the old row and insert a
/// duplicate. Items colliding on that key get their id appended, the lowest
/// id keeping the plain key so the outcome does not depend on list order.
SynologyMappedEntries synologyEntriesFrom(
  List<Object?> items, {
  required SynologyShareLink link,
  required bool downloadsAllowed,
}) {
  final warnings = <String>[];
  final photos = <_Photo>[];
  for (final (index, raw) in items.indexed) {
    if (raw is! Map<String, Object?>) {
      warnings.add('item $index: not an object');
      continue;
    }
    if (raw['type'] != 'photo') continue;
    final photo = _Photo.tryParse(raw);
    if (photo == null) {
      // Field names, never values: enough to see what Synology renamed,
      // nothing about the photo.
      final keys = [...raw.keys]..sort();
      final additional = raw['additional'];
      final extra = additional is Map<String, Object?>
          ? ' additional: ${([...additional.keys]..sort()).join(', ')}'
          : '';
      warnings.add(
        'item $index: missing id, time, size or cache key '
        '(fields: ${keys.join(', ')};$extra)',
      );
      continue;
    }
    photos.add(photo);
  }

  final byBaseKey = <String, List<_Photo>>{};
  for (final photo in photos) {
    byBaseKey.putIfAbsent(photo.baseKey, () => []).add(photo);
  }
  final keyOf = <_Photo, String>{};
  for (final group in byBaseKey.values) {
    final sorted = [...group]..sort((a, b) => a.id.compareTo(b.id));
    for (final (i, photo) in sorted.indexed) {
      keyOf[photo] = i == 0 ? photo.baseKey : '${photo.baseKey}-i${photo.id}';
    }
  }

  final entries = [
    for (final photo in photos)
      ManifestEntry(
        entryKey: keyOf[photo]!,
        url:
            (downloadsAllowed
                    ? link.originalUri(id: photo.id, cacheKey: photo.cacheKey)
                    : link.thumbnailUri(
                        id: photo.id,
                        cacheKey: photo.cacheKey,
                        size: SynologyThumbnailSize.xl,
                      ))
                .toString(),
        // Synology stores the capture time as local wall clock seconds read
        // as UTC: the same convention as MediaItem.takenAt.
        takenAt: DateTime.fromMillisecondsSinceEpoch(
          photo.time * 1000,
          isUtc: true,
        ),
        width: photo.width,
        height: photo.height,
        mediaType: 'photo',
        metadataComplete: true,
        filename: photo.filename,
      ),
  ];
  return (entries: entries, warnings: warnings);
}

class _Photo {
  const _Photo({
    required this.id,
    required this.time,
    required this.filesize,
    required this.cacheKey,
    this.filename,
    this.width,
    this.height,
  });

  final int id;
  final int time;
  final int filesize;
  final String cacheKey;
  final String? filename;
  final int? width;
  final int? height;

  String get baseKey => 't$time-s$filesize';

  static _Photo? tryParse(Map<String, Object?> raw) {
    final id = raw['id'];
    final time = raw['time'];
    final filesize = raw['filesize'];
    if (id is! int || time is! int || filesize is! int) return null;
    final additional = raw['additional'];
    if (additional is! Map<String, Object?>) return null;
    final thumbnail = additional['thumbnail'];
    final cacheKey = thumbnail is Map<String, Object?>
        ? thumbnail['cache_key']
        : null;
    if (cacheKey is! String || cacheKey.isEmpty) return null;
    final resolution = additional['resolution'];
    int? dimension(String name) {
      if (resolution is! Map<String, Object?>) return null;
      final value = resolution[name];
      return value is int && value > 0 ? value : null;
    }

    return _Photo(
      id: id,
      time: time,
      filesize: filesize,
      cacheKey: cacheKey,
      filename: raw['filename'] is String ? raw['filename'] as String : null,
      width: dimension('width'),
      height: dimension('height'),
    );
  }
}

class _SessionLost implements Exception {
  const _SessionLost(this.sid);

  final String sid;
}
