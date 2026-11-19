import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';

/// Confirming a tag the app applied is an edit a photo's sitting holds until
/// Save, like tagging and untagging (issue #4727).
void main() {
  const appTag = SpeciesTagChip(
    speciesId: 'sp_a',
    storedName: 'Queen Parrotfish',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
    unconfirmed: true,
  );
  const handTag = SpeciesTagChip(
    speciesId: 'sp_b',
    storedName: 'Blue Tang',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  test('confirming shows the tag as the diver\'s own', () {
    final edits = SpeciesTagEdits.none.confirming('sp_a');

    expect(edits.isEmpty, isFalse);
    expect(edits.applyTo(const [appTag, handTag]), [
      appTag.copyWith(unconfirmed: false),
      handTag,
    ]);
  });

  test('untagging a confirmed tag drops the confirm', () {
    final edits = SpeciesTagEdits.none
        .confirming('sp_a')
        .toggled(appTag, tagged: false, stored: const [appTag]);

    expect(edits.confirmed, isEmpty);
    expect(edits.applyTo(const [appTag]), isEmpty);
  });

  test('a confirm the store has made moot is pruned', () {
    final edits = SpeciesTagEdits.none.confirming('sp_a');

    expect(
      edits.prunedTo([appTag.copyWith(unconfirmed: false)]).isEmpty,
      isTrue,
    );
    expect(edits.prunedTo(const []).isEmpty, isTrue);
    expect(edits.prunedTo(const [appTag]).confirmed, {'sp_a'});
  });

  test('tagging by hand a species the app tagged meanwhile confirms it', () {
    // Added in the sitting before the app's tag landed underneath it.
    final edits = SpeciesTagEdits.none.toggled(
      appTag.copyWith(unconfirmed: false),
      tagged: true,
      stored: const [],
    );
    expect(edits.applyTo(const [appTag]), [
      appTag.copyWith(unconfirmed: false),
    ]);
  });

  test('a hand add the app tagged underneath survives the rebase as a '
      'confirm', () {
    final edits = SpeciesTagEdits.none
        .toggled(
          appTag.copyWith(unconfirmed: false),
          tagged: true,
          stored: const [],
        )
        .prunedTo(const [appTag]);
    expect(edits.confirmed, {'sp_a'});
    expect(edits.applyTo(const [appTag]), [
      appTag.copyWith(unconfirmed: false),
    ]);
  });

  test('tagging by hand a species the app already tagged confirms it: the '
      'diver named it (a fish named from a video frame, the picker)', () {
    final edits = SpeciesTagEdits.none.toggled(
      appTag.copyWith(unconfirmed: false),
      tagged: true,
      stored: const [appTag],
    );

    expect(edits.confirmed, {'sp_a'});
    expect(edits.applyTo(const [appTag]), [
      appTag.copyWith(unconfirmed: false),
    ]);
  });

  test('tagging by hand a species the diver already tagged is no edit', () {
    final edits = SpeciesTagEdits.none.toggled(
      handTag,
      tagged: true,
      stored: const [handTag],
    );

    expect(edits.isEmpty, isTrue);
  });
}
