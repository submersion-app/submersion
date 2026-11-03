import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';

/// In a browser an export is a download (issue #4121): the shared helpers
/// hand the bytes to the download seam and write nothing to a documents
/// directory the page does not have.
void main() {
  tearDown(() => debugBrowserDownload = null);

  test('bytes go to the browser download with their name and type', () async {
    final downloads = <(Uint8List, String, String)>[];
    debugBrowserDownload = (bytes, fileName, mimeType) async {
      downloads.add((bytes, fileName, mimeType));
      return fileName;
    };
    final path = await saveAndShareFileBytes(
      [1, 2, 3],
      'dives.csv',
      'text/csv',
    );
    expect(path, 'dives.csv');
    expect(downloads.single.$1, [1, 2, 3]);
    expect(downloads.single.$2, 'dives.csv');
    expect(downloads.single.$3, 'text/csv');
  });

  test('text goes the same way, UTF-8 encoded', () async {
    final downloads = <(Uint8List, String, String)>[];
    debugBrowserDownload = (bytes, fileName, mimeType) async {
      downloads.add((bytes, fileName, mimeType));
      return fileName;
    };
    await saveAndShareFile('<uddf/>', 'dives.uddf', 'application/xml');
    expect(String.fromCharCodes(downloads.single.$1), '<uddf/>');
    expect(downloads.single.$2, 'dives.uddf');
  });
}
