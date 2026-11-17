import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

SpeciesTagChip _species(String id) => SpeciesTagChip(
  speciesId: id,
  storedName: id,
  category: SpeciesCategory.fish,
  isBuiltIn: false,
);

final _at = DateTime.utc(2026, 11, 1);

MediaPersonChip _person(
  String id, {
  String? buddyId,
  String? diverId,
  FaceBox? box,
  Duration? at,
  String? name,
}) => MediaPersonChip(
  tag: MediaPersonTag(
    id: id,
    mediaId: 'm1',
    buddyId: buddyId,
    diverId: diverId,
    box: box,
    videoPosition: at,
    createdAt: _at,
    updatedAt: _at,
  ),
  buddyName: name,
);

const _boxA = FaceBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2);
const _boxB = FaceBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2);

void main() {
  group('SpeciesTagEdits', () {
    final stored = [_species('turtle')];

    test('species toggled on and off again is no edit', () {
      final edits = SpeciesTagEdits.none
          .toggled(_species('ray'), tagged: true, stored: stored)
          .toggled(_species('ray'), tagged: false, stored: stored);

      expect(edits.isEmpty, isTrue);
      expect(edits, SpeciesTagEdits.none);
    });

    test('a stored species untagged then tagged again is no edit', () {
      final edits = SpeciesTagEdits.none
          .toggled(_species('turtle'), tagged: false, stored: stored)
          .toggled(_species('turtle'), tagged: true, stored: stored);

      expect(edits, SpeciesTagEdits.none);
    });

    test('applyTo keeps a stored tag the edits never named', () {
      final edits = SpeciesTagEdits.none
          .toggled(_species('turtle'), tagged: false, stored: stored)
          .toggled(_species('ray'), tagged: true, stored: stored);
      // A tag synced in from another device during the sitting.
      final storedNow = [_species('turtle'), _species('shark')];

      expect(edits.applyTo(storedNow).map((c) => c.speciesId), [
        'shark',
        'ray',
      ]);
    });

    test('a species added that is stored by then is not doubled', () {
      final edits = SpeciesTagEdits.none.toggled(
        _species('ray'),
        tagged: true,
        stored: stored,
      );

      expect(
        edits
            .applyTo([_species('turtle'), _species('ray')])
            .map((c) => c.speciesId),
        ['turtle', 'ray'],
      );
    });
  });

  group('SpeciesTagEdits against a store that moved (issue #4527)', () {
    test('tagging again, after the species was untagged underneath too, '
        'tags it', () {
      final edits = SpeciesTagEdits.none.toggled(
        _species('turtle'),
        tagged: false,
        stored: [_species('turtle')],
      );
      // Another device untagged it as well.
      const storedNow = <SpeciesTagChip>[];

      final again = edits.toggled(
        _species('turtle'),
        tagged: true,
        stored: storedNow,
      );

      expect(again.applyTo(storedNow).map((c) => c.speciesId), ['turtle']);
    });

    test('untagging a held tag, after it was tagged underneath too, '
        'untags it', () {
      final edits = SpeciesTagEdits.none.toggled(
        _species('ray'),
        tagged: true,
        stored: const [],
      );
      final storedNow = [_species('ray')];

      final again = edits.toggled(
        _species('ray'),
        tagged: false,
        stored: storedNow,
      );

      expect(again.applyTo(storedNow), isEmpty);
    });

    test('prunedTo drops the edits the store has made moot', () {
      final edits = SpeciesTagEdits(
        added: {'ray': _species('ray'), 'shark': _species('shark')},
        removed: const {'turtle', 'eel'},
      );

      final pruned = edits.prunedTo([_species('ray'), _species('eel')]);

      expect(pruned.added.keys, ['shark']);
      expect(pruned.removed, {'eel'});
      expect(
        const SpeciesTagEdits(removed: {'turtle'}).prunedTo(const []),
        SpeciesTagEdits.none,
      );
    });
  });

  group('PersonTagEdits', () {
    final stored = [_person('t1', buddyId: 'b1', box: _boxA, name: 'Ann')];

    test('a person added then removed is no edit', () {
      final added = PersonTagEdits.none.add(
        _person('local1', buddyId: 'b2', box: _boxB, name: 'Bo'),
        stored: stored,
        isVideo: false,
      );
      final edits = added.remove('local1', stored: stored);

      expect(edits.isEmpty, isTrue);
      expect(edits, PersonTagEdits.none);
    });

    test('a person added who duplicates a shown tag moves its box', () {
      final edits = PersonTagEdits.none.add(
        _person('local1', buddyId: 'b1', box: _boxB, name: 'Ann'),
        stored: stored,
        isVideo: false,
      );

      final shown = edits.applyTo(stored);
      expect(shown, hasLength(1));
      expect(shown.single.tag.id, 't1');
      expect(shown.single.tag.box, _boxB);
    });

    test('a person tagged again without a spot adds nothing', () {
      final edits = PersonTagEdits.none.add(
        _person('local1', buddyId: 'b1', name: 'Ann'),
        stored: stored,
        isVideo: false,
      );

      expect(edits, PersonTagEdits.none);
    });

    test('on a video, a second moment of one person is a tag of its own', () {
      final video = [
        _person(
          't1',
          buddyId: 'b1',
          box: _boxA,
          at: const Duration(seconds: 2),
        ),
      ];
      final edits = PersonTagEdits.none.add(
        _person(
          'local1',
          buddyId: 'b1',
          box: _boxB,
          at: const Duration(seconds: 9),
        ),
        stored: video,
        isVideo: true,
      );

      expect(edits.applyTo(video), hasLength(2));
    });

    test('a stored tag changed back is no edit', () {
      final moved = stored.single.copyWith(
        tag: stored.single.tag.copyWith(box: _boxB, updatedAt: DateTime.now()),
      );
      final back = stored.single.copyWith(
        tag: stored.single.tag.copyWith(box: _boxA, updatedAt: DateTime.now()),
      );
      final edits = PersonTagEdits.none
          .change(moved, stored: stored)
          .change(back, stored: stored);

      expect(edits, PersonTagEdits.none);
    });

    test('a held tag changed stays a held add', () {
      final added = PersonTagEdits.none.add(
        _person('local1', buddyId: 'b2', box: _boxB, name: 'Bo'),
        stored: stored,
        isVideo: false,
      );
      final reassigned = _person('local1', buddyId: 'b3', box: _boxB);
      final edits = added.change(reassigned, stored: stored);

      expect(edits.added.single.tag.buddyId, 'b3');
      expect(edits.changed, isEmpty);
    });

    test('applyTo drops a change to a tag no longer stored', () {
      final moved = stored.single.copyWith(
        tag: stored.single.tag.copyWith(box: _boxB),
      );
      final edits = PersonTagEdits.none.change(moved, stored: stored);

      expect(edits.applyTo(const []), isEmpty);
    });

    test('applyTo keeps a tag the edits never named', () {
      final edits = PersonTagEdits.none.remove('t1', stored: stored);
      final storedNow = [...stored, _person('t9', diverId: 'me')];

      expect(edits.applyTo(storedNow).map((c) => c.tag.id), ['t9']);
    });
  });

  group('PersonTagEdits.prunedTo (issue #4527)', () {
    test('drops removals and changes of tags no longer stored, and changes '
        'the store has caught up with', () {
      final stored = [
        _person('t1', buddyId: 'ann', box: _boxA),
        _person('t2', buddyId: 'bo', box: _boxA),
      ];
      final edits = PersonTagEdits.none
          .remove('t1', stored: stored)
          .change(
            _person('t2', buddyId: 'bo', box: _boxB),
            stored: stored,
          )
          .add(_person('new', buddyId: 'cy'), stored: stored, isVideo: false);
      // Another device removed t1 and moved t2 to the same spot.
      final storedNow = [_person('t2', buddyId: 'bo', box: _boxB)];

      final pruned = edits.prunedTo(storedNow);

      expect(pruned.removed, isEmpty);
      expect(pruned.changed, isEmpty);
      expect(pruned.added.map((c) => c.tag.id), ['new']);
    });
  });

  group('MediaTagEdits (#1970 tags)', () {
    Tag tag(String id) => Tag(
      id: id,
      name: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    test('the tags chosen, as edits on the stored ones', () {
      final edits = MediaTagEdits.between(
        [tag('wreck'), tag('night')],
        [tag('night'), tag('macro')],
      );

      expect(edits.added.keys, ['macro']);
      expect(edits.removed, {'wreck'});
    });

    test('the stored tags chosen again is no edit', () {
      expect(
        MediaTagEdits.between([tag('wreck')], [tag('wreck')]),
        MediaTagEdits.none,
      );
    });

    test('prunedTo drops the edits the store has made moot', () {
      final edits = MediaTagEdits.between(
        [tag('wreck'), tag('night')],
        [tag('night'), tag('macro'), tag('reef')],
      );

      final pruned = edits.prunedTo([tag('night'), tag('macro')]);

      expect(pruned.added.keys, ['reef']);
      expect(pruned.removed, isEmpty);
    });

    test('applyTo keeps a tag the edits never named', () {
      final edits = MediaTagEdits.between([tag('wreck')], [tag('macro')]);

      expect(edits.applyTo([tag('wreck'), tag('synced')]).map((t) => t.id), [
        'synced',
        'macro',
      ]);
    });
  });
}
