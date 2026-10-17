/// What a master-detail summary pane shows when nothing is selected.
enum SummaryPaneView {
  /// The calm animated scene with a few facts on it.
  scene,

  /// The data-rich summary widget.
  details;

  /// Parse from a stored name, defaulting to [scene] for null or unknown.
  static SummaryPaneView fromName(String? name) {
    return SummaryPaneView.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SummaryPaneView.scene,
    );
  }
}
