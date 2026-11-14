import 'package:submersion/core/buoyancy/body_composition.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Repository provider
final diverWeightEntryRepositoryProvider = Provider<DiverWeightEntryRepository>(
  (ref) {
    return DiverWeightEntryRepository();
  },
);

/// Dated body-mass entries for the active diver, newest first.
///
/// Self-invalidates whenever the `diver_weight_entries` table changes (a
/// sync apply, a local create/edit/delete, ...).
final diverWeightEntriesProvider = FutureProvider<List<DiverWeightEntry>>((
  ref,
) async {
  final repository = ref.watch(diverWeightEntryRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];

  ref.invalidateSelfWhen(repository.watchChanges());

  return repository.getEntriesForDiver(diverId);
});

/// The active diver's most recent body-mass entry (null when none recorded).
final latestDiverWeightProvider = FutureProvider<DiverWeightEntry?>((
  ref,
) async {
  final entries = await ref.watch(diverWeightEntriesProvider.future);
  return entries.isEmpty ? null : entries.first;
});

/// The active diver's most recent recorded height in centimetres: the newest
/// entry that carries a plausible one. Height is optional per entry and
/// changes far more slowly than weight, so a newer weight-only entry must not
/// discard it. Implausible stored values (the history page never validated
/// height) are skipped so they neither prefill the planner nor reach the
/// calibration.
final latestDiverHeightProvider = FutureProvider<double?>((ref) async {
  final entries = await ref.watch(diverWeightEntriesProvider.future);
  for (final entry in entries) {
    final height = entry.heightCm;
    if (height != null && BodyComposition.isPlausibleHeight(height)) {
      return height;
    }
  }
  return null;
});

/// The active diver's most recent body fat percentage: the newest entry
/// that carries a plausible one (issue #4525). Like height it is optional
/// per entry, so a newer weight-only entry must not discard it.
final latestDiverBodyFatProvider = FutureProvider<double?>((ref) async {
  final entries = await ref.watch(diverWeightEntriesProvider.future);
  for (final entry in entries) {
    final bodyFat = entry.bodyFatPercent;
    if (bodyFat != null && BodyComposition.isPlausibleBodyFat(bodyFat)) {
      return bodyFat;
    }
  }
  return null;
});

/// What the active diver's profile says about their build beyond weight
/// and height: sex, and age today from the birth year. Both sharpen the
/// body fat estimate, and either may be missing.
typedef DiverBodyProfile = ({DiverSex? sex, int? ageYears});

final diverBodyProfileProvider = FutureProvider<DiverBodyProfile>((ref) async {
  final diver = await ref.watch(currentDiverProvider.future);
  return (
    sex: diver?.sex,
    ageYears: BodyComposition.ageYears(
      birthYear: diver?.birthYear,
      at: DateTime.now(),
    ),
  );
});
