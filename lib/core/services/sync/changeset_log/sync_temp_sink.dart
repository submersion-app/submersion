/// A temporary sync file being written.
///
/// Appends in order through [add]; [writeAt] patches bytes already written
/// (the base export fills its checksum in over a placeholder once the data
/// section has streamed past). [close] returns the path the file is read
/// back through.
abstract interface class SyncTempSink {
  /// The path the file is read back and deleted through, known from
  /// creation so a failed write can still clean up.
  String get path;

  /// Bytes written so far, which is the offset the next [add] lands at.
  int get length;

  Future<void> add(List<int> bytes);

  /// Overwrites [bytes] at [offset], which must lie within what was written.
  Future<void> writeAt(int offset, List<int> bytes);

  Future<String> close();
}
