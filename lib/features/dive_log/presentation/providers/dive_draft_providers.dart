import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The draft dive repository (issue #637), over the shared dive repository
/// so its writes tick the same dive change stream.
final diveDraftRepositoryProvider = Provider<DiveDraftRepository>((ref) {
  return DiveDraftRepository(dives: ref.watch(diveRepositoryProvider));
});

/// The current diver's drafts, newest entry first. Follows the dives table,
/// so a draft made, filled or completed elsewhere shows up.
final draftDivesProvider = FutureProvider.autoDispose<List<Dive>>((ref) {
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  return ref.watch(diveDraftRepositoryProvider).getDrafts(diverId: diverId);
});

/// The dive open on this device, whoever's it is (issue #637): the one the
/// marks act on, so the buttons and the lock screen offer Surfaced for it
/// even after a diver switch.
final markingDraftProvider = FutureProvider.autoDispose<Dive?>((ref) {
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  return ref.watch(diveDraftRepositoryProvider).openDraftFor(null);
});
