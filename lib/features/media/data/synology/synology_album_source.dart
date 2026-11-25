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
/// Photos, videos (as their 720p conversion when Synology made one) and
/// live photos (as their still frame) are read; other item types are
/// skipped. See
/// `docs/design/specs/2026-11-21-synology-photos-shared-album-design.md`.
class SynologyAlbumSource {
  SynologyAlbumSource({
    required http.Client client,
    required SynologyShareSessions sessions,
    required Future<String?> Function(SynologyShareLink link) passwordFor,
    this.pageSize = 1000,
    this.maxPages = 100,
    this.requestTimeout = kSynologyRequestTimeout,
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

  /// How long one call may take. A share that never answers fails the
  /// fetch as unreachable instead of holding the poll cycle forever.
  final Duration requestTimeout;

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

    // A listing that spans pages is read by offset, so an item added or
    // removed while it is read shifts the later pages: one item listed
    // twice, or one never listed, which the poller would mark missing on
    // every device. Such a listing is read again until two reads agree.
    var listing = await _listItems(link, sid);
    if (listing.pages > 1) {
      for (var attempt = 1; ; attempt++) {
        final again = await _listItems(link, sid);
        if (_sameItems(listing.items, again.items)) break;
        if (attempt == _maxListingAttempts) {
          throw const SynologyShareException(
            SynologyShareErrorKind.unexpected,
            'The album kept changing while it was read',
          );
        }
        listing = again;
      }
    }
    final items = _uniqueById(listing.items);

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

  /// How many times a multi-page listing is read again before a share that
  /// keeps changing fails the fetch.
  static const _maxListingAttempts = 3;

  /// Every item of the album, page by page, and how many pages it took.
  Future<({List<Object?> items, int pages})> _listItems(
    SynologyShareLink link,
    String sid,
  ) async {
    final items = <Object?>[];
    for (var page = 0; page < maxPages; page++) {
      final data = await _call(link, sid, {
        'api': 'SYNO.Foto.Browse.Item',
        'method': 'list',
        'version': '1',
        'offset': '${page * pageSize}',
        'limit': '$pageSize',
        'passphrase': link.code,
        'additional': '["thumbnail","resolution","video_meta","video_convert"]',
      });
      final list = data['list'];
      if (list is! List<Object?>) {
        throw const SynologyShareException(
          SynologyShareErrorKind.unexpected,
          'The share sent no item list',
        );
      }
      items.addAll(list);
      if (list.length < pageSize) return (items: items, pages: page + 1);
    }
    throw const SynologyShareException(
      SynologyShareErrorKind.unexpected,
      'The album is larger than this client reads',
    );
  }

  /// Whether two listings name the same items, in any order. Items that tie
  /// on the share's sort key (a burst taken in one second) may come back in
  /// another order on each read; only an item doubled, added or missing is
  /// a change.
  static bool _sameItems(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    final idsA = _sortedIds(a);
    final idsB = _sortedIds(b);
    for (var i = 0; i < idsA.length; i++) {
      if (idsA[i] != idsB[i]) return false;
    }
    return true;
  }

  /// The ids of [items] as sortable text, sorted; an item without an id
  /// counts as an empty one, so two such reads still compare equal.
  static List<String> _sortedIds(List<Object?> items) =>
      [for (final item in items) '${_idOf(item) ?? ''}']..sort();

  static Object? _idOf(Object? item) =>
      item is Map<String, Object?> ? item['id'] : null;

  /// [items] with each Synology id kept once. Items without an id stay, so
  /// the mapping still reports them as malformed.
  static List<Object?> _uniqueById(List<Object?> items) {
    final seen = <Object>{};
    return [
      for (final item in items)
        if (_idOf(item) == null || seen.add(_idOf(item)!)) item,
    ];
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
      response = await _client
          .post(
            link.apiUri,
            headers: SynologyShareSessions.sessionHeaders(link, sid),
            body: form,
          )
          .timeout(requestTimeout);
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
/// because it was malformed or has nothing to play. Item types this client
/// does not import are skipped silently. [unplayable] counts the videos
/// skipped because the share offers no conversion and no download: they
/// read fine, so they say nothing about the list's format.
typedef SynologyMappedEntries = ({
  List<ManifestEntry> entries,
  List<String> warnings,
  int unplayable,
});

/// Why [items] look like a list this client no longer understands, or null
/// when they read normally.
///
/// A changed API must fail the fetch, never pass as a smaller album: the
/// poller reads every entry missing from a successful fetch as removed and
/// marks its row missing on every device. So a list whose items carry no
/// type this client knows, or whose items mostly fail to parse, is a
/// failure. A few unreadable items are not: those are skipped with a
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
  // Every imported type counts: they are all read the same way. Videos
  // that parsed but have nothing to play here (a view-only share before
  // Synology converted them) are not unreadable and are left out.
  final readable = typed - mapped.unplayable;
  if (readable > 0 && mapped.entries.length * 2 < readable) {
    final first = mapped.warnings.isEmpty
        ? ''
        : ' First: ${mapped.warnings.first}';
    return 'Album format not recognised: only ${mapped.entries.length} of '
        '$readable items could be read.$first';
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
    final kind = _ItemKind.of(raw['type']);
    if (kind == null) continue;
    final photo = _Photo.tryParse(raw, kind);
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

  final urls = <_Photo, Uri>{};
  var unplayable = 0;
  for (final photo in photos) {
    final url = _urlFor(photo, link, downloadsAllowed);
    if (url == null) {
      unplayable++;
      warnings.add('video ${photo.id}: no conversion to play and no downloads');
    } else {
      urls[photo] = url;
    }
  }
  final entries = [
    for (final photo in photos)
      if (urls[photo] case final url?)
        ManifestEntry(
          entryKey: keyOf[photo]!,
          url: url.toString(),
          // Synology stores the capture time as local wall clock seconds read
          // as UTC: the same convention as MediaItem.takenAt.
          takenAt: DateTime.fromMillisecondsSinceEpoch(
            photo.time * 1000,
            isUtc: true,
          ),
          width: photo.width,
          height: photo.height,
          durationSeconds: photo.kind == _ItemKind.video
              ? photo.durationSeconds
              : null,
          mediaType: photo.kind == _ItemKind.video ? 'video' : 'photo',
          metadataComplete: true,
          filename: photo.filename,
        ),
  ];
  return (entries: entries, warnings: warnings, unplayable: unplayable);
}

/// Where an item's row points:
/// - a photo: its original, or the xl rendition when the share allows no
///   downloads;
/// - a live photo: the xl rendition, its still frame (the original is the
///   still and the motion clip together, which no viewer here shows);
/// - a video: Synology's 720p conversion when it has one, much smaller than
///   the original and what a phone plays without stalling, else the
///   original file, else (a share without downloads) another conversion it
///   lists. Never a conversion it does not list. The original stays one tap
///   away ([SynologyShareLink.originalFor]) where the share allows it.
///
/// Null for a video with nothing to play here: no conversion listed and no
/// downloads allowed.
Uri? _urlFor(_Photo item, SynologyShareLink link, bool downloadsAllowed) {
  switch (item.kind) {
    case _ItemKind.video:
      if (item.conversions.contains('high')) {
        return link.streamUri(
          id: item.id,
          cacheKey: item.cacheKey,
          downloadsAllowed: downloadsAllowed,
        );
      }
      if (downloadsAllowed) {
        return link.originalUri(id: item.id, cacheKey: item.cacheKey);
      }
      for (final quality in const ['medium', 'low', 'orig_h264']) {
        if (item.conversions.contains(quality)) {
          return link.streamUri(
            id: item.id,
            cacheKey: item.cacheKey,
            quality: quality,
            downloadsAllowed: false,
          );
        }
      }
      return null;
    case _ItemKind.live:
      return link.thumbnailUri(
        id: item.id,
        cacheKey: item.cacheKey,
        size: SynologyThumbnailSize.xl,
      );
    case _ItemKind.photo:
      return downloadsAllowed
          ? link.originalUri(id: item.id, cacheKey: item.cacheKey)
          : link.thumbnailUri(
              id: item.id,
              cacheKey: item.cacheKey,
              size: SynologyThumbnailSize.xl,
            );
  }
}

/// The item types this client imports.
enum _ItemKind {
  photo,
  video,
  live;

  static _ItemKind? of(Object? type) => switch (type) {
    'photo' => photo,
    'video' => video,
    'live' => live,
    _ => null,
  };
}

/// One album item this client imports: a photo, a video or a live photo.
class _Photo {
  const _Photo({
    required this.kind,
    required this.id,
    required this.time,
    required this.filesize,
    required this.cacheKey,
    this.filename,
    this.width,
    this.height,
    this.durationSeconds,
    this.conversions = const {},
  });

  final _ItemKind kind;
  final int id;
  final int time;
  final int filesize;
  final String cacheKey;
  final String? filename;
  final int? width;
  final int? height;

  /// A video's length, from `video_meta.duration` (milliseconds).
  final int? durationSeconds;

  /// The qualities of the conversions Synology lists for this video
  /// (`high` is its 720p rendition).
  final Set<String> conversions;

  String get baseKey => 't$time-s$filesize';

  static _Photo? tryParse(Map<String, Object?> raw, _ItemKind kind) {
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

    final meta = additional['video_meta'];
    final durationMs = meta is Map<String, Object?> ? meta['duration'] : null;
    final converted = additional['video_convert'];
    final conversions = <String>{
      if (converted is List<Object?>)
        for (final c in converted)
          if (c is Map<String, Object?> && c['quality'] is String)
            c['quality']! as String,
    };

    return _Photo(
      kind: kind,
      id: id,
      time: time,
      filesize: filesize,
      cacheKey: cacheKey,
      filename: raw['filename'] is String ? raw['filename'] as String : null,
      width: dimension('width'),
      height: dimension('height'),
      durationSeconds: durationMs is num && durationMs > 0
          ? (durationMs / 1000).round()
          : null,
      conversions: conversions,
    );
  }
}

class _SessionLost implements Exception {
  const _SessionLost(this.sid);

  final String sid;
}
