import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/file_saver.dart';

/// Natively an export leaves through the share sheet or the save dialog
/// (file_export_utils); the browser download seam is the web's alone.
void main() {
  test('is not a browser download natively', () {
    expect(FileSaver.isBrowserDownload, isFalse);
  });

  test('saving through it natively is a programming error', () {
    expect(
      () => FileSaver.saveBytes(
        Uint8List.fromList([1, 2, 3]),
        fileName: 'x.bin',
        mimeType: 'application/octet-stream',
      ),
      throwsUnsupportedError,
    );
  });
}
