import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// The dive's annotations (#4109) that its Notes still link, in time order.
/// Refreshed by the analysis-input tick, which the event table feeds, and by
/// the dive itself (a Notes edit can orphan one). Its own provider, not a
/// branch of the analysis: an annotation is the diver's, drawn whether or
/// not the dive has an analysis to run.
final diveAnnotationsProvider = FutureProvider.autoDispose
    .family<List<ProfileEvent>, String>((ref, diveId) async {
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchAnalysisInputChanges(),
      );
      // Before the awaits: a write during them re-runs this provider, and a
      // watch from the run it replaced throws.
      final repository = ref.watch(annotationRepositoryProvider);
      final dive = await ref.watch(diveProvider(diveId).future);
      final annotations = await repository.annotationsForDive(diveId);
      return dropOrphanAnnotations(annotations, dive?.notes ?? '');
    });

/// The events a chart draws: the analysis's events without any annotation
/// rows it carries, then [annotations]. The result keeps its identity while
/// both inputs do, so a host rebuild (a hover move) hands the chart the same
/// list and its didUpdateWidget stays quiet. Null when there is nothing.
List<ProfileEvent>? mergeChartEvents(
  List<ProfileEvent>? analysisEvents,
  List<ProfileEvent> annotations,
) {
  if (analysisEvents == null) return annotations.isEmpty ? null : annotations;
  final cached = _mergedEvents[analysisEvents];
  if (cached != null && identical(cached.annotations, annotations)) {
    return cached.merged;
  }
  final merged = <ProfileEvent>[
    for (final e in analysisEvents)
      if (!e.isAnnotation) e,
    ...annotations,
  ];
  _mergedEvents[analysisEvents] = (annotations: annotations, merged: merged);
  return merged;
}

final _mergedEvents =
    Expando<({List<ProfileEvent> annotations, List<ProfileEvent> merged})>();
