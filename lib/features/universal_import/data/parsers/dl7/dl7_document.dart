/// Typed model of a scanned DAN DL7 document.
///
/// Segment field lists keep the tag at index 0 so spec field numbering maps
/// directly to list indices (spec field N = index N). Profile rows have the
/// leading empty token (from the row's leading pipe) removed, so spec
/// column N = index N-1.
class Dl7Document {
  /// FSH file-header fields, empty when the segment is missing.
  final List<String> fshFields;

  /// ZRH record-header fields (units live here), empty when missing.
  final List<String> zrhFields;

  /// Raw text inside the first ZAR{...} block, empty string when absent.
  final String zarContent;

  /// One record per ZDH/ZDP/ZDT group, in file order.
  final List<Dl7DiveRecord> dives;

  /// Structural anomalies observed while scanning (missing ZDT, orphan
  /// segments). These become import warnings, not errors.
  final List<String> readerWarnings;

  const Dl7Document({
    this.fshFields = const [],
    this.zrhFields = const [],
    this.zarContent = '',
    this.dives = const [],
    this.readerWarnings = const [],
  });
}

/// One dive's segments: ZDH fields, profile rows, ZDT fields.
class Dl7DiveRecord {
  final List<String> zdhFields;
  final List<List<String>> zdpRows;

  /// Empty when the file ended before the dive's ZDT.
  final List<String> zdtFields;

  const Dl7DiveRecord({
    required this.zdhFields,
    this.zdpRows = const [],
    this.zdtFields = const [],
  });
}
