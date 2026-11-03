import 'package:sqlite3/common.dart';

const String _unavailable = 'Raw SQLite access is native only';

/// Browser implementation of the raw SQLite facade.
///
/// The browser database lives behind a drift worker, so there is no handle to
/// hand out here. Every open throws; [isAvailable] lets callers skip the work
/// instead of catching.
abstract final class RawSqlite {
  /// Always false in a browser.
  static bool get isAvailable => false;

  /// Throws [UnsupportedError]: there is no raw handle in the browser.
  static CommonDatabase open(
    String path, {
    OpenMode mode = OpenMode.readWriteCreate,
  }) => throw UnsupportedError(_unavailable);

  /// Throws [UnsupportedError]: there is no raw handle in the browser.
  static CommonDatabase openInMemory() => throw UnsupportedError(_unavailable);
}
