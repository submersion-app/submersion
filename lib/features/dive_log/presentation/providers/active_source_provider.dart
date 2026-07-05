import 'package:submersion/core/providers/provider.dart';

/// The data source whose data drives the dive detail page (chart, stat
/// chips, deco and tissue cards). Null means "the primary source" so the
/// page needs no async initialization. View state only: switching the
/// active source never writes isPrimary; that changes solely via the
/// explicit "Set as primary" action. autoDispose: leaving the dive resets
/// the selection, so reopening a dive always starts at the primary source.
final activeDiveSourceProvider = StateProvider.autoDispose
    .family<String?, String>((ref, diveId) => null);

/// Source IDs currently overlaid on the profile chart for comparison.
/// The active source is never a member; activating a source removes it.
final overlaySourcesProvider = StateProvider.autoDispose
    .family<Set<String>, String>((ref, diveId) => const {});
