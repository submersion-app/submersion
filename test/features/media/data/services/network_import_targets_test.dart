import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/network_import_targets.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';

class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingDiveRepo implements DiveRepository {
  @override
  Future<List<Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async => throw StateError('dives unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ResolvedNetworkMedia resolved(
  String url, {
  DateTime? takenAt,
  String? failure,
}) => ResolvedNetworkMedia(
  uri: Uri.parse(url),
  failure: failure,
  result: takenAt == null
      ? null
      : UrlExtractionResult(url: url, finalUrl: url, takenAt: takenAt),
);

Dive dive(String id, DateTime start) => Dive(
  id: id,
  dateTime: start,
  entryTime: start,
  exitTime: start.add(const Duration(minutes: 50)),
);

void main() {
  final a = resolved(
    'https://e.com/a.jpg',
    takenAt: DateTime.utc(2026, 6, 12, 9, 10),
  );
  final b = resolved(
    'https://e.com/b.jpg',
    takenAt: DateTime.utc(2026, 6, 13, 9, 10),
  );
  final broken = resolved('https://e.com/c.jpg', failure: 'HTTP 404');

  test('requestsForTarget attaches everything to the dive', () {
    final requests = requestsForTarget([
      a,
      broken,
    ], const DiveAttachTarget('d1'));
    expect(requests.map((r) => r.diveId), ['d1', 'd1']);
    expect(requests.map((r) => r.siteId), [null, null]);
  });

  test('requestsForTarget attaches everything to the site', () {
    final requests = requestsForTarget([a], const SiteAttachTarget('s1'));
    expect(requests.single.siteId, 's1');
    expect(requests.single.diveId, isNull);
  });

  test('candidatesFor keys on the uri and carries takenAt and error', () {
    final candidates = candidatesFor([a, broken]);
    expect(candidates[0].key, 'https://e.com/a.jpg');
    expect(candidates[0].takenAt, DateTime.utc(2026, 6, 12, 9, 10));
    expect(candidates[0].title, 'a.jpg');
    expect(candidates[1].error, 'HTTP 404');
    expect(candidates[1].takenAt, isNull);
  });

  test('candidatesFor gives every row a url preview, failures included', () {
    final candidates = candidatesFor([a, broken]);
    expect(
      candidates[0].preview,
      const UrlImportPreview('https://e.com/a.jpg'),
    );
    // A failed fetch still has a URL, and the art may well load even when
    // the metadata probe did not.
    expect(candidates[1].preview, isA<UrlImportPreview>());
  });

  test('candidatesFor prefers a manifest caption, then a custom title', () {
    const entry = ManifestEntry(
      entryKey: 'k1',
      url: 'https://e.com/m.jpg',
      caption: 'Reef at dawn',
    );
    final withCaption = ResolvedNetworkMedia(
      uri: Uri.parse(entry.url),
      entry: entry,
    );

    expect(candidatesFor([withCaption]).single.title, 'Reef at dawn');
    expect(
      candidatesFor([withCaption], title: (m) => m.uri.host).single.title,
      'e.com',
    );
  });

  test('requestsFromReview keeps only decided items', () {
    final requests = requestsFromReview(
      [a, b, broken],
      {
        'https://e.com/a.jpg': const DiveAttachTarget('d1'),
        'https://e.com/c.jpg': const SiteAttachTarget('s1'),
      },
    );
    expect(requests, hasLength(2));
    expect(requests[0].media, same(a));
    expect(requests[0].diveId, 'd1');
    expect(requests[1].media, same(broken));
    expect(requests[1].siteId, 's1');
  });

  test('requestsForConfidentMatches inserts confident only', () async {
    final matcher = DiveLinkMatcher(
      diveRepository: _FakeDiveRepo([dive('d1', DateTime(2026, 6, 12, 9))]),
    );

    final out = await requestsForConfidentMatches([a, b, broken], matcher);

    expect(out.requests.single.media, same(a));
    expect(out.requests.single.diveId, 'd1');
    expect(out.skipped, 2);
  });

  test(
    'a matcher failure skips that entry instead of aborting the batch',
    () async {
      final matcher = DiveLinkMatcher(diveRepository: _ThrowingDiveRepo());

      final out = await requestsForConfidentMatches([a, b], matcher);

      expect(out.requests, isEmpty);
      expect(out.skipped, 2);
    },
  );
}
