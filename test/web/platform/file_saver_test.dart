@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/file_saver.dart';

/// A browser's export is a download (issue #4121): a Blob behind an object
/// URL, handed to an anchor with the file's name.
void main() {
  tearDown(() => FileSaver.debugDownload = null);

  test('is the browser download', () {
    expect(FileSaver.isBrowserDownload, isTrue);
  });

  test('offers the bytes as a blob URL under the file name', () async {
    String? url;
    String? name;
    FileSaver.debugDownload = (u, n) {
      url = u;
      name = n;
    };
    final bytes = Uint8List.fromList(List.generate(300, (i) => i & 0xff));
    await FileSaver.saveBytes(
      bytes,
      fileName: 'dives.csv',
      mimeType: 'text/csv',
    );
    expect(name, 'dives.csv');
    expect(url, startsWith('blob:'));
    final response = await web.window.fetch(url!.toJS).toDart;
    expect(response.headers.get('content-type'), 'text/csv');
    final buffer = await response.arrayBuffer().toDart;
    expect(buffer.toDart.asUint8List(), bytes);
  });
}
