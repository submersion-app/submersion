import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  test('round-trips every field', () {
    final filter = MediaLibraryFilter(
      mediaType: MediaType.video,
      siteId: 's1',
      tripId: 't1',
      diveId: 'd1',
      fromDate: DateTime(2026, 6, 1),
      toDate: DateTime(2026, 6, 30),
      sourceType: MediaSourceType.localFile,
      health: MediaHealthFilter.missing,
    );

    expect(MediaLibraryFilter.fromJson(filter.toJson()), filter);
  });

  test('an empty filter round-trips to none', () {
    expect(
      MediaLibraryFilter.fromJson(MediaLibraryFilter.none.toJson()),
      MediaLibraryFilter.none,
    );
  });

  test('unknown enum values decode to null rather than throwing', () {
    final decoded = MediaLibraryFilter.fromJson({
      'mediaType': 'hologram',
      'health': 'exploded',
      'sourceType': 'telepathy',
    });
    expect(decoded.mediaType, isNull);
    expect(decoded.health, isNull);
    expect(decoded.sourceType, isNull);
  });

  test('an album saved with the retired unlinked facet decodes to none', () {
    // Every row carries a dive or site link now, so the facet is gone; an
    // album a pre-upgrade build wrote must degrade to "no constraint"
    // rather than take the library view down.
    expect(MediaLibraryFilter.fromJson({'health': 'unlinked'}).health, isNull);
  });

  test('malformed dates decode to null rather than throwing', () {
    final decoded = MediaLibraryFilter.fromJson({
      'fromDate': 'yesterday',
      'toDate': null,
    });
    expect(decoded.fromDate, isNull);
    expect(decoded.toDate, isNull);
  });

  group('dates cross a timezone intact', () {
    // Album filters are calendar bounds, not instants: the repository
    // normalises them with the same wall-clock-as-UTC rule that taken_at
    // uses. Encoding the local *instant* would therefore hand a device in
    // another zone a different calendar day. These tests pin the encoding
    // to a value that does not depend on the host's UTC offset.
    test('encode the wall-clock components, not the local instant', () {
      final filter = MediaLibraryFilter(
        fromDate: DateTime(2026, 6, 1),
        toDate: DateTime(2026, 6, 30, 23, 59, 59, 999),
      );
      final json = filter.toJson();

      expect(json['fromDate'], DateTime.utc(2026, 6, 1).millisecondsSinceEpoch);
      expect(
        json['toDate'],
        DateTime.utc(2026, 6, 30, 23, 59, 59, 999).millisecondsSinceEpoch,
      );
    });

    test('decode wall-clock millis back to the same calendar digits', () {
      final decoded = MediaLibraryFilter.fromJson({
        'fromDate': DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
        'toDate': DateTime.utc(
          2026,
          6,
          30,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch,
      });

      expect(decoded.fromDate, DateTime(2026, 6, 1));
      expect(decoded.toDate, DateTime(2026, 6, 30, 23, 59, 59, 999));
      expect(decoded.fromDate!.isUtc, isFalse);
    });
  });

  group('value equality', () {
    // Smart albums and the library providers both key off filters, so value
    // semantics are load-bearing: an identity-based filter would make two
    // equal albums look different and re-run every query on rebuild.
    test('filters with the same fields are equal and hash alike', () {
      // Deliberately built at runtime with their own DateTime instances.
      // Two identical `const` filters would be canonicalized to the same
      // object, so a set check would pass on identity and prove nothing
      // about == or hashCode.
      MediaLibraryFilter build() => MediaLibraryFilter(
        siteId: 's1',
        tripId: 't1',
        diveId: 'd1',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.mediaStore,
        health: MediaHealthFilter.missing,
        fromDate: DateTime(2026, 6, 1),
      );
      final a = build();
      final b = build();

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      final seen = <MediaLibraryFilter>{a};
      expect(seen.contains(b), isTrue);
    });

    test('a difference in any single field breaks equality', () {
      const base = MediaLibraryFilter(siteId: 's1');
      expect(base == const MediaLibraryFilter(siteId: 's2'), isFalse);
      expect(base == const MediaLibraryFilter(tripId: 's1'), isFalse);
      expect(base == const MediaLibraryFilter(diveId: 's1'), isFalse);
      expect(
        base ==
            const MediaLibraryFilter(siteId: 's1', mediaType: MediaType.photo),
        isFalse,
      );
      expect(
        base ==
            const MediaLibraryFilter(
              siteId: 's1',
              sourceType: MediaSourceType.localFile,
            ),
        isFalse,
      );
      expect(
        base ==
            const MediaLibraryFilter(
              siteId: 's1',
              health: MediaHealthFilter.missing,
            ),
        isFalse,
      );
      expect(
        base == MediaLibraryFilter(siteId: 's1', fromDate: DateTime(2026)),
        isFalse,
      );
      expect(
        base == MediaLibraryFilter(siteId: 's1', toDate: DateTime(2026)),
        isFalse,
      );
    });

    test('the empty filter equals none and reports itself empty', () {
      expect(const MediaLibraryFilter(), MediaLibraryFilter.none);
      expect(MediaLibraryFilter.none.isEmpty, isTrue);
      expect(const MediaLibraryFilter(siteId: 's1').isEmpty, isFalse);
    });

    test('a round trip through JSON preserves equality', () {
      const filter = MediaLibraryFilter(
        siteId: 's1',
        health: MediaHealthFilter.missing,
      );
      final restored = MediaLibraryFilter.fromJson(filter.toJson());
      expect(restored, filter);
      expect(restored.hashCode, filter.hashCode);
    });
  });
}
