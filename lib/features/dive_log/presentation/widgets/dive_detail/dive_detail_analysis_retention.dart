import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart'
    show ProfileAnalysis;
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart'
    show DiveSourceKey;

/// The last usable profile analyses the page's analysis cards rendered, each
/// paired with the dive and source it belongs to.
///
/// A transient null from `profileAnalysisProvider`, e.g. a mid-sync
/// `getDiveById` reading the dive while its profile rows are being rewritten,
/// must keep those cards visible rather than collapsing them. A dive that has
/// genuinely never produced an analysis never populates this, so it still
/// shows nothing. The `watchDiveDetailChanges` debounce makes transient nulls
/// rare; this makes the cards robust even to a single ill-timed tick.
///
/// Only the same source gets its analysis back. Moving to another source is
/// not a blip in a read, and falling back across it would pass one computer's
/// deco off as another's.
///
/// One instance lives as long as the page, because the cards come and go
/// inside it: the two deco cards share what they retain, and the pairing gate
/// beside Cylinders reads what the "SAC Rate by Segment" card retained.
class DiveDetailAnalysisRetention {
  ProfileAnalysis? _decoPanel;
  DiveSourceKey? _decoPanelKey;
  ProfileAnalysis? _sacSegments;
  DiveSourceKey? _sacSegmentsKey;

  /// The analysis the deco, tissue and O2 cards last rendered for [key].
  ProfileAnalysis? decoPanelFor(DiveSourceKey key) =>
      _decoPanelKey == key ? _decoPanel : null;

  void retainDecoPanel(DiveSourceKey key, ProfileAnalysis analysis) {
    _decoPanel = analysis;
    _decoPanelKey = key;
  }

  /// The analysis the "SAC Rate by Segment" card last rendered for [key].
  ProfileAnalysis? sacSegmentsFor(DiveSourceKey key) =>
      _sacSegmentsKey == key ? _sacSegments : null;

  void retainSacSegments(DiveSourceKey key, ProfileAnalysis analysis) {
    _sacSegments = analysis;
    _sacSegmentsKey = key;
  }
}
