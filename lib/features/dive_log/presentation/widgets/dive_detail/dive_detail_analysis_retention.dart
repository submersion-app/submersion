import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart'
    show ProfileAnalysis;

/// The last usable profile analyses the page's analysis cards rendered, each
/// paired with the dive it belongs to.
///
/// A transient null from [profileAnalysisProvider], e.g. a mid-sync
/// `getDiveById` reading the dive while its profile rows are being rewritten,
/// must keep those cards visible rather than collapsing them. A dive that has
/// genuinely never produced an analysis never populates this, so it still
/// shows nothing. The `watchDiveDetailChanges` debounce makes transient nulls
/// rare; this makes the cards robust even to a single ill-timed tick.
///
/// One instance lives as long as the page, because the cards come and go
/// inside it: the two deco cards share what they retain, and the pairing gate
/// beside Cylinders reads what the "SAC Rate by Segment" card retained.
class DiveDetailAnalysisRetention {
  ProfileAnalysis? _decoPanel;
  String? _decoPanelDiveId;
  ProfileAnalysis? _sacSegments;
  String? _sacSegmentsDiveId;

  /// The analysis the deco, tissue and O2 cards last rendered for [diveId].
  ProfileAnalysis? decoPanelFor(String diveId) =>
      _decoPanelDiveId == diveId ? _decoPanel : null;

  void retainDecoPanel(String diveId, ProfileAnalysis analysis) {
    _decoPanel = analysis;
    _decoPanelDiveId = diveId;
  }

  /// The analysis the "SAC Rate by Segment" card last rendered for [diveId].
  ProfileAnalysis? sacSegmentsFor(String diveId) =>
      _sacSegmentsDiveId == diveId ? _sacSegments : null;

  void retainSacSegments(String diveId, ProfileAnalysis analysis) {
    _sacSegments = analysis;
    _sacSegmentsDiveId = diveId;
  }
}
