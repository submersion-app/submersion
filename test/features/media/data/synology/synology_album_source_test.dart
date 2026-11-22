import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/features/media/data/synology/synology_api.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/data/synology/synology_share_sessions.dart';

final _link = SynologyShareLink.tryParseShareLink(
  Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
)!;

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _ok(Map<String, Object?> data) =>
    _json({'success': true, 'data': data});

http.Response _error(int code) => _json({
  'success': false,
  'error': {'code': code},
});

Map<String, Object?> _photo(
  int id, {
  int time = 1781190186,
  int filesize = 5000,
  String type = 'photo',
  String? cacheKey,
  int width = 4000,
  int height = 3000,
}) => {
  'id': id,
  'filename': 'P$id.JPG',
  'filesize': filesize,
  'time': time,
  'type': type,
  'additional': {
    'resolution': {'width': width, 'height': height},
    'thumbnail': {'cache_key': cacheKey ?? '${id}_77'},
  },
};

/// A share serving [items] in pages; scripted failures are injected through
/// [onList].
class _FakeAlbum {
  _FakeAlbum(
    this.items, {
    this.privacyType = 'public-download',
    this.password = 'secret',
  });

  static const name = 'Dives';
  final List<Map<String, Object?>> items;
  final String privacyType;

  /// The share's password; empty for a share without one.
  final String password;
  int logins = 0;
  final List<int> listedOffsets = [];
  String? current;
  http.Response? Function(int offset)? onList;

  Future<http.Response> handle(http.Request request) async {
    final form = request.bodyFields;
    switch (form['api']) {
      case 'SYNO.Core.Sharing.Login':
        logins++;
        if (form['password'] != password) return _error(1001);
        current = 'sid-$logins';
        return _ok({'sharing_sid': current});
      case 'SYNO.Foto.Browse.Album':
        if (request.headers['cookie'] != 'sharing_sid=$current') {
          return _error(kSynologyNoSession);
        }
        return _ok({
          'list': [
            {
              'id': 185,
              'name': name,
              'item_count': items.length,
              'additional': {
                'sharing_info': {'privacy_type': privacyType},
              },
            },
          ],
        });
      case 'SYNO.Foto.Browse.Item':
        if (request.headers['cookie'] != 'sharing_sid=$current' ||
            request.headers['x-syno-sharing'] != 'code1') {
          return _error(kSynologyNoSession);
        }
        final offset = int.parse(form['offset']!);
        final limit = int.parse(form['limit']!);
        listedOffsets.add(offset);
        final scripted = onList?.call(offset);
        if (scripted != null) return scripted;
        final page = items.skip(offset).take(limit).toList();
        return _ok({'list': page});
    }
    return _error(103);
  }
}

SynologyAlbumSource _source(
  _FakeAlbum album, {
  String? password = 'secret',
  int pageSize = 1000,
}) {
  final client = MockClient(album.handle);
  return SynologyAlbumSource(
    client: client,
    sessions: SynologyShareSessions(client: client),
    passwordFor: (_) async => password,
    pageSize: pageSize,
  );
}

void main() {
  test('maps photos to complete manifest entries', () async {
    final album = _FakeAlbum([_photo(41197, cacheKey: '41197_1781199161')]);
    final outcome = await _source(album).fetch(_link);

    expect(outcome, isA<ManifestFetchSuccess>());
    final parsed = (outcome as ManifestFetchSuccess).parsed;
    expect(parsed.title, 'Dives');
    expect(parsed.format, ManifestFormat.json);
    final entry = parsed.entries.single;
    expect(entry.entryKey, 't1781190186-s5000');
    expect(entry.takenAt, DateTime.utc(2026, 6, 11, 15, 3, 6));
    expect(entry.width, 4000);
    expect(entry.height, 3000);
    expect(entry.mediaType, 'photo');
    expect(entry.metadataComplete, isTrue);
    expect(entry.filename, 'P41197.JPG');
    expect(entry.caption, isNull);
    expect(
      Uri.parse(entry.url),
      _link.originalUri(id: 41197, cacheKey: '41197_1781199161'),
    );
  });

  test('skips videos, live photos and unknown types', () async {
    final album = _FakeAlbum([
      _photo(1),
      _photo(2, type: 'video', time: 2),
      _photo(3, type: 'live', time: 3),
      _photo(4, type: 'other', time: 4),
    ]);
    final parsed =
        ((await _source(album).fetch(_link)) as ManifestFetchSuccess).parsed;
    expect(parsed.entries, hasLength(1));
  });

  test('skips malformed items with a warning', () async {
    // Most photos readable: the malformed minority is skipped, not fatal.
    final album = _FakeAlbum([
      _photo(1),
      _photo(4, time: 4),
      _photo(5, time: 5),
      {'id': 'not-a-number', 'type': 'photo'},
      {'id': 3, 'type': 'photo', 'time': 3, 'filesize': 3},
    ]);
    final parsed =
        ((await _source(album).fetch(_link)) as ManifestFetchSuccess).parsed;
    expect(parsed.entries, hasLength(3));
    expect(parsed.warnings, hasLength(2));
  });

  test('points entries at the xl rendition when downloads are off', () async {
    final album = _FakeAlbum([
      _photo(7, cacheKey: '7_1'),
    ], privacyType: 'public-view');
    final parsed =
        ((await _source(album).fetch(_link)) as ManifestFetchSuccess).parsed;
    expect(
      Uri.parse(parsed.entries.single.url),
      _link.thumbnailUri(
        id: 7,
        cacheKey: '7_1',
        size: SynologyThumbnailSize.xl,
      ),
    );
  });

  test('keeps keys unique when capture time and size collide', () async {
    final album = _FakeAlbum([
      _photo(30, time: 100, filesize: 9),
      _photo(10, time: 100, filesize: 9),
      _photo(20, time: 100, filesize: 9),
    ]);
    final parsed =
        ((await _source(album).fetch(_link)) as ManifestFetchSuccess).parsed;
    final keys = parsed.entries.map((e) => e.entryKey).toList();
    // The lowest id keeps the plain key, whatever order the share lists them.
    expect(keys, containsAll(['t100-s9', 't100-s9-i20', 't100-s9-i30']));
    expect(keys.toSet(), hasLength(3));
  });

  test('a moved photo keeps its key even with a new id', () async {
    final before =
        ((await _source(_FakeAlbum([_photo(1)])).fetch(_link))
                as ManifestFetchSuccess)
            .parsed
            .entries
            .single;
    final after =
        ((await _source(_FakeAlbum([_photo(999)])).fetch(_link))
                as ManifestFetchSuccess)
            .parsed
            .entries
            .single;
    expect(after.entryKey, before.entryKey);
    expect(after.url, isNot(before.url));
  });

  test('pages through the album', () async {
    final album = _FakeAlbum([for (var i = 1; i <= 5; i++) _photo(i, time: i)]);
    final parsed =
        ((await _source(album, pageSize: 2).fetch(_link))
                as ManifestFetchSuccess)
            .parsed;
    expect(parsed.entries, hasLength(5));
    expect(album.listedOffsets, [0, 2, 4]);
  });

  test('a failing page fails the whole fetch, never a partial list', () async {
    final album = _FakeAlbum([for (var i = 1; i <= 5; i++) _photo(i, time: i)])
      ..onList = (offset) => offset == 2 ? _error(500) : null;
    final outcome = await _source(album, pageSize: 2).fetch(_link);
    expect(outcome, isA<ManifestFetchFailure>());
  });

  test('a lost session is renewed once', () async {
    final album = _FakeAlbum([_photo(1)]);
    var failOnce = true;
    album.onList = (_) {
      if (!failOnce) return null;
      failOnce = false;
      return _error(kSynologyNoSession);
    };
    final outcome = await _source(album).fetch(_link);
    expect(outcome, isA<ManifestFetchSuccess>());
    expect(album.logins, 2);
  });

  test('a session that keeps failing is a failure, not a loop', () async {
    final album = _FakeAlbum([_photo(1)])
      ..onList = (_) => _error(kSynologyNoSession);
    final outcome = await _source(album).fetch(_link);
    expect(outcome, isA<ManifestFetchFailure>());
    expect(album.logins, 2);
  });

  test('no stored password is unauthorized', () async {
    final outcome = await _source(
      _FakeAlbum([_photo(1)]),
      password: null,
    ).fetch(_link);
    expect(outcome, isA<ManifestFetchFailure>());
    expect((outcome as ManifestFetchFailure).unauthorized, isTrue);
    // Asked for, not refused: the form shows no red reason for this one.
    expect(outcome.message, kSynologyPasswordMissingMessage);
  });

  test('a share without a password is read without one', () async {
    final album = _FakeAlbum([_photo(1)], password: '');
    final outcome = await _source(album, password: null).fetch(_link);
    expect(outcome, isA<ManifestFetchSuccess>());
    expect(album.logins, 1);
  });

  group('a changed list format fails the fetch instead of emptying it', () {
    test('items with no known type', () async {
      final album = _FakeAlbum([
        {..._photo(1), 'type': 'image'},
        {..._photo(2, time: 2), 'type': 'image'},
      ]);
      final outcome = await _source(album).fetch(_link);
      expect(outcome, isA<ManifestFetchFailure>());
      final message = (outcome as ManifestFetchFailure).message;
      expect(message, contains('Album format not recognised'));
      expect(message, contains('image'));
      expect(outcome.unauthorized, isFalse);
    });

    test('photos that mostly cannot be read', () async {
      Map<String, Object?> renamed(int id) {
        final p = Map<String, Object?>.of(_photo(id, time: id));
        p['taken_time'] = p.remove('time');
        return p;
      }

      final album = _FakeAlbum([_photo(1), renamed(2), renamed(3)]);
      final outcome = await _source(album).fetch(_link);
      expect(outcome, isA<ManifestFetchFailure>());
      final message = (outcome as ManifestFetchFailure).message;
      expect(message, contains('only 1 of 3 photos'));
      // Field names, so a developer sees what changed; no values.
      expect(message, contains('taken_time'));
      expect(message, isNot(contains('P2.JPG')));
    });

    test('a few unreadable photos are only skipped', () async {
      final album = _FakeAlbum([
        _photo(1),
        _photo(2, time: 2),
        {'id': 3, 'type': 'photo'},
      ]);
      final outcome = await _source(album).fetch(_link);
      expect(outcome, isA<ManifestFetchSuccess>());
      final parsed = (outcome as ManifestFetchSuccess).parsed;
      expect(parsed.entries, hasLength(2));
      expect(parsed.warnings.single, contains('fields: id, type'));
    });

    test('an album of videos only is not a format problem', () async {
      final album = _FakeAlbum([_photo(1, type: 'video')]);
      final outcome = await _source(album).fetch(_link);
      expect(outcome, isA<ManifestFetchSuccess>());
      expect((outcome as ManifestFetchSuccess).parsed.entries, isEmpty);
    });
  });

  test('a wrong password is unauthorized', () async {
    final outcome = await _source(
      _FakeAlbum([_photo(1)]),
      password: 'wrong',
    ).fetch(_link);
    expect((outcome as ManifestFetchFailure).unauthorized, isTrue);
  });

  test('an unreachable share is a plain failure', () async {
    final source = SynologyAlbumSource(
      client: MockClient((_) async => throw http.ClientException('down')),
      sessions: SynologyShareSessions(
        client: MockClient((_) async => throw http.ClientException('down')),
      ),
      passwordFor: (_) async => 'secret',
    );
    final outcome = await source.fetch(_link);
    expect(outcome, isA<ManifestFetchFailure>());
    expect((outcome as ManifestFetchFailure).unauthorized, isFalse);
  });
}
