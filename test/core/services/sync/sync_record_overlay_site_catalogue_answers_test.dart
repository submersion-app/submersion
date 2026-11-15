// What a diver settled about catalogue records, for a personal site and
// for a library site's per-profile record. A peer on a build from before
// the columns sends neither key, and its edit of the other fields must not
// strip what this device holds.
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_record_overlay.dart';

void main() {
  const answers = '{"not":["osm_node_3"]}';

  test("an older peer's site keeps our answers", () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'name': 'Salt Pier South'},
      {'id': 's1', 'name': 'Salt Pier', 'catalogueAnswers': answers},
    );

    expect(merged['name'], 'Salt Pier South');
    expect(merged['catalogueAnswers'], answers);
  });

  test("a current peer's answers arrive as sent", () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'name': 'Salt Pier', 'catalogueAnswers': answers},
      {'id': 's1', 'name': 'Salt Pier'},
    );

    expect(merged['catalogueAnswers'], answers);
  });

  test("a current peer's row with no answers clears ours", () {
    // Undoing a merge on the peer takes its answers back; that is its
    // decision about the row, sent explicitly as null.
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'name': 'Salt Pier', 'catalogueAnswers': null},
      {'id': 's1', 'name': 'Salt Pier', 'catalogueAnswers': answers},
    );

    expect(merged['catalogueAnswers'], isNull);
  });

  test("an older peer's library notes keep our link and answers", () {
    final merged = overlayOntoLocal(
      'librarySiteNotes',
      {'id': 'd1:s1', 'notes': 'Park by the pier'},
      {
        'id': 'd1:s1',
        'notes': '',
        'catalogueId': 'osm_node_1',
        'catalogueAnswers': answers,
      },
    );

    expect(merged['notes'], 'Park by the pier');
    expect(merged['catalogueId'], 'osm_node_1');
    expect(merged['catalogueAnswers'], answers);
  });
}
