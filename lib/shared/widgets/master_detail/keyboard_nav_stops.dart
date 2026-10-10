/// Where a grouped list's keyboard cursor can rest, in display order (#3065).
///
/// Built row by row in the order the list draws them. A collapsible group's
/// header is a stop of its own, so a collapsed group can be reached and
/// opened with Right; the rows of an open group follow it and remember which
/// header they fold into, for Left. Lists without groups only add rows.
class KeyboardNavStops {
  final List<String> _keys = [];
  final Map<String, String> _headerGroups = {};
  final Map<String, String> _rowHeaders = {};

  /// Every stop, in display order.
  List<String> get keys => List.unmodifiable(_keys);

  /// Adds the header stop [key] for the collapsible group [groupId].
  void addHeader(String key, String groupId) {
    _keys.add(key);
    _headerGroups[key] = groupId;
  }

  /// Adds the row stop [key], inside the group headed by [header] if any.
  void addRow(String key, {String? header}) {
    _keys.add(key);
    if (header != null) _rowHeaders[key] = header;
  }

  /// The group a header stop belongs to, or null when [key] is a row.
  String? groupOfHeader(String key) => _headerGroups[key];

  /// The header [key] folds into: itself for a header, its group's header for
  /// a row inside an open group, and null for a row in no group.
  String? headerFor(String key) =>
      _headerGroups.containsKey(key) ? key : _rowHeaders[key];
}
