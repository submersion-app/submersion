import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';

/// The gear a photo's sitting linked and unlinked (issue #5046), held as
/// edits on the stored links.
void main() {
  test('between gives added and removed ids', () {
    final edits = MediaGearEdits.between(['a', 'b'], ['b', 'c']);
    expect(edits.added, {'c'});
    expect(edits.removed, {'a'});
    expect(MediaGearEdits.between(['a'], ['a']).isEmpty, isTrue);
  });

  test('applyTo keeps a stored link the edits never name', () {
    final edits = MediaGearEdits.between(['a'], ['b']);
    // Another device linked 'x' while the sitting was open.
    expect(edits.applyTo(['a', 'x']), ['x', 'b']);
  });

  test('prunedTo drops an add already stored and a remove already gone', () {
    const edits = MediaGearEdits(added: {'b', 'c'}, removed: {'a', 'z'});
    final pruned = edits.prunedTo(['a', 'b']);
    expect(pruned.added, {'c'});
    expect(pruned.removed, {'a'});
  });
}
