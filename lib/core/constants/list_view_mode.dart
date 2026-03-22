/// Which layout to use for list views.
enum ListViewMode {
  /// Full-size card with all details
  detailed,

  /// Two-line compact card
  compact,

  /// Single-row flat, divider-separated
  dense;

  /// Parse from stored string, defaulting to detailed.
  static ListViewMode fromName(String name) {
    return ListViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ListViewMode.detailed,
    );
  }
}
