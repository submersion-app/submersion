import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/series_source_owner.dart';

void main() {
  final at = DateTime.utc(2026, 7, 1);
  DiveDataSource source(String id, {String? computerId}) => DiveDataSource(
    id: id,
    diveId: 'd1',
    computerId: computerId,
    isPrimary: id == 'a',
    importedAt: at,
    createdAt: at,
  );

  group('seriesSourceOwner (#4296)', () {
    final sources = [
      source('a', computerId: 'pc1'),
      source('b', computerId: 'pc2'),
      source('c'),
      source('d'),
    ];

    test('a row naming a source belongs to it', () {
      expect(
        seriesSourceOwner(sourceId: 'b', computerId: 'pc1', sources: sources),
        'b',
      );
    });

    test('a row naming a source the dive no longer has belongs to none', () {
      expect(
        seriesSourceOwner(sourceId: 'gone', computerId: null, sources: sources),
        isNull,
      );
    });

    test('an unattributed row belongs to the one source of its computer', () {
      expect(
        seriesSourceOwner(sourceId: null, computerId: 'pc2', sources: sources),
        'b',
      );
    });

    test(
      'an unattributed row of a computer two sources share is no one\'s',
      () {
        expect(
          seriesSourceOwner(
            sourceId: null,
            computerId: 'pc1',
            sources: [
              ...sources,
              source('e', computerId: 'pc1'),
            ],
          ),
          isNull,
        );
      },
    );

    test('a row naming neither is no one\'s, even with file imports', () {
      expect(
        seriesSourceOwner(sourceId: null, computerId: null, sources: sources),
        isNull,
      );
    });
  });

  group('seriesSourceOwnerAmong (#4367)', () {
    const sources = [(id: 'a', computerId: 'pc1'), (id: 'b', computerId: null)];

    test('reads ownership by the same rule as seriesSourceOwner', () {
      expect(
        seriesSourceOwnerAmong(
          sourceId: 'b',
          computerId: null,
          sources: sources,
        ),
        'b',
      );
      expect(
        seriesSourceOwnerAmong(
          sourceId: null,
          computerId: 'pc1',
          sources: sources,
        ),
        'a',
      );
      expect(
        seriesSourceOwnerAmong(
          sourceId: null,
          computerId: null,
          sources: sources,
        ),
        isNull,
      );
    });
  });
}
