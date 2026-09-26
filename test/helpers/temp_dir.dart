import 'dart:io';

/// Deletes a temp directory a test created, retrying while the platform still
/// holds a handle to something inside it.
///
/// Windows refuses to unlink an open file, and a widget test routinely stops
/// pumping the moment the widget under test appears -- before the read that
/// produced it has closed its file. POSIX unlinks an open file happily, so a
/// plain `delete` passes on Linux and CI and fails only for someone developing
/// on Windows (issue #2279). The handle is released once the pending read
/// finishes, which is why a bounded retry is enough.
///
/// Cleanup is best effort: a directory under the system temp root is the OS's
/// to reclaim, and failing a test whose assertions already passed would report
/// a problem the code under test does not have.
Future<void> deleteTempDir(Directory dir) async {
  for (var attempt = 0; attempt < _attempts; attempt++) {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(_backoff);
    }
  }
}

const _attempts = 30;
const _backoff = Duration(milliseconds: 100);
