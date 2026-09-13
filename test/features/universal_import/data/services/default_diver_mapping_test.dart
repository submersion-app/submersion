import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/default_diver_mapping.dart';

Diver _profile(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _ann = SourceDiver(key: 'macdive:ann', name: 'Ann Lee', diveCount: 10);
const _bo = SourceDiver(key: 'macdive:bo', name: 'Bo Ray', diveCount: 4);
const _cy = SourceDiver(key: 'macdive:cy', name: 'Cy Park', diveCount: 2);
const _unowned = SourceDiver(
  key: SourceDiver.unownedKey,
  name: '',
  diveCount: 1,
);

void main() {
  group('DiverTarget', () {
    test('target keys round trip', () {
      const existing = ExistingDiverTarget('p1');
      const created = NewDiverTarget('macdive:ann');
      expect(DiverTarget.diverIdOf(existing.targetKey), 'p1');
      expect(DiverTarget.newSourceKeyOf(existing.targetKey), isNull);
      expect(DiverTarget.newSourceKeyOf(created.targetKey), 'macdive:ann');
      expect(DiverTarget.diverIdOf(created.targetKey), isNull);
      expect(const SkipDiverTarget().targetKey, isNull);
    });

    test('targets compare by value', () {
      expect(const ExistingDiverTarget('p1'), const ExistingDiverTarget('p1'));
      expect(
        const NewDiverTarget('a') == const ExistingDiverTarget('a'),
        isFalse,
      );
    });
  });

  group('defaultDiverMapping', () {
    test('a name match wins, ignoring case and outer spaces', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_ann, _bo],
        profiles: [_profile('me', 'Me'), _profile('p-bo', '  bo RAY ')],
        activeDiverId: 'me',
      );
      expect(mapping[_bo.key], const ExistingDiverTarget('p-bo'));
      expect(mapping[_ann.key], const ExistingDiverTarget('me'));
    });

    test('the busiest unmatched diver gets the active profile', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_cy, _bo, _ann],
        profiles: [_profile('me', 'Me')],
        activeDiverId: 'me',
      );
      expect(mapping, {
        _ann.key: const ExistingDiverTarget('me'),
        _bo.key: NewDiverTarget(_bo.key),
        _cy.key: NewDiverTarget(_cy.key),
      });
    });

    test('an active profile claimed by a name match is not given twice', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_ann, _bo],
        profiles: [_profile('me', 'Bo Ray')],
        activeDiverId: 'me',
      );
      expect(mapping, {
        _bo.key: const ExistingDiverTarget('me'),
        _ann.key: NewDiverTarget(_ann.key),
      });
    });

    test('dives with no diver go to the active profile', () {
      final mapping = defaultDiverMapping(
        sourceDivers: const [_ann, _bo, _unowned],
        profiles: [_profile('me', 'Ann Lee')],
        activeDiverId: 'me',
      );
      expect(mapping[SourceDiver.unownedKey], const ExistingDiverTarget('me'));
    });
  });
}
