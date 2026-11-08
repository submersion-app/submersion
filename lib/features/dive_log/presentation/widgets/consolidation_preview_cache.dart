import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

typedef _PreviewKey = ({String? primaryId, ConsolidationAlignment alignment});

/// The combine dialog's consolidation classification and plan, kept until
/// the primary or the alignment changes. Both run the profile aligner (the
/// plan's best fit on realigned records, the classification on every
/// overlapping one, #4296), so neither is redone on every frame.
class ConsolidationPreviewCache {
  ConsolidationPreviewCache(this.dives);

  final List<Dive> dives;

  String? _classificationPrimaryId;
  DiveConsolidationClassification? _classification;
  _PreviewKey? _planKey;
  DiveConsolidationPlan? _plan;

  /// Always with a mode, so a selection that does not overlap (or only
  /// partly does) is offered for alignment instead of rejected (#552).
  /// Kept per primary only: classify reads whether a mode is given, never
  /// which, so flipping the toggle does not search the fits again.
  DiveConsolidationClassification classification({
    required String? primaryId,
    required ConsolidationAlignment alignment,
  }) {
    final cached = _classification;
    if (cached != null && _classificationPrimaryId == primaryId) return cached;
    _classificationPrimaryId = primaryId;
    return _classification = const DiveConsolidationBuilder().classify(
      dives,
      primaryDiveId: primaryId,
      alignment: alignment,
    );
  }

  DiveConsolidationPlan plan({
    required String? primaryId,
    required ConsolidationAlignment alignment,
  }) {
    final key = (primaryId: primaryId, alignment: alignment);
    final cached = _plan;
    if (cached != null && _planKey == key) return cached;
    _planKey = key;
    return _plan = const DiveConsolidationBuilder().build(
      dives,
      primaryDiveId: primaryId,
      alignment: alignment,
      classified: classification(primaryId: primaryId, alignment: alignment),
    );
  }
}
