// A site's link to the built-in catalogue record it was adopted from. A
// peer on a build from before the column sends no `catalogueId`, and its
// edit of the site's other fields must not strip the link this device holds.
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_record_overlay.dart';

void main() {
  test("an older peer's row keeps our link", () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'name': 'Salt Pier South'},
      {'id': 's1', 'name': 'Salt Pier', 'catalogueId': 'osm_node_1'},
    );

    expect(merged['name'], 'Salt Pier South');
    expect(merged['catalogueId'], 'osm_node_1');
  });

  test("a current peer's link arrives as sent", () {
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'name': 'Salt Pier', 'catalogueId': 'osm_node_1'},
      {'id': 's1', 'name': 'Salt Pier'},
    );

    expect(merged['catalogueId'], 'osm_node_1');
  });

  test("a current peer's merge that dropped the link drops ours", () {
    // A merge on the peer can leave a survivor unlinked; that is its
    // decision about the row, sent explicitly as null.
    final merged = overlayOntoLocal(
      'diveSites',
      {'id': 's1', 'name': 'Salt Pier', 'catalogueId': null},
      {'id': 's1', 'name': 'Salt Pier', 'catalogueId': 'osm_node_1'},
    );

    expect(merged['catalogueId'], isNull);
  });
}
