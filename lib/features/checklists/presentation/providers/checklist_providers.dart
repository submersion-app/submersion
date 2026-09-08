import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Repository singletons
final checklistTemplateRepositoryProvider =
    Provider<ChecklistTemplateRepository>(
      (ref) => ChecklistTemplateRepository(),
    );

final tripChecklistRepositoryProvider = Provider<TripChecklistRepository>(
  (ref) => TripChecklistRepository(),
);

/// All checklist templates for the active diver.
final checklistTemplatesProvider =
    FutureProvider<List<domain.ChecklistTemplate>>((ref) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getAllTemplates(diverId: diverId);
    });

/// Single template by id.
final checklistTemplateProvider =
    FutureProvider.family<domain.ChecklistTemplate?, String>((ref, id) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getTemplateById(id);
    });

/// Items of a template, ordered by sortOrder.
final checklistTemplateItemsProvider =
    FutureProvider.family<List<domain.ChecklistTemplateItem>, String>((
      ref,
      templateId,
    ) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getItemsForTemplate(templateId);
    });

/// A trip's checklist items, ordered by sortOrder. Self-invalidates on
/// table changes so sync-applied edits render live.
final tripChecklistProvider =
    FutureProvider.family<List<domain.TripChecklistItem>, String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());
      return repository.getByTripId(tripId);
    });

/// Done/total progress for a trip's checklist.
final tripChecklistProgressProvider =
    FutureProvider.family<({int done, int total}), String>((ref, tripId) async {
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());
      return repository.getProgress(tripId);
    });

/// The one trip checklist worth surfacing on the home screen, or null.
///
/// Home used to offer a single checklist button and it went to the pre-dive
/// runs, so a trip's to-do list -- a different feature, a different table --
/// was only ever reachable by opening the trip, and a diver following the
/// home button landed on a page headed "Pre-Dive Checklists" instead. This
/// gives the trip list its own home surface, under its own label.
///
/// A trip already under way wins over one still ahead, since that is the
/// checklist being worked through today. Trips with nothing on their list are
/// skipped: an empty row would be a permanent no-op on the home screen.
///
/// Both tests read the one captured [now] through the entity's own date-only
/// helpers. `Trip.isInProgress` would re-read `DateTime.now()` per trip, and
/// pairing it with an instant comparison on `startDate` mixed two clocks and
/// two granularities in a single pass: a trip starting today read as under
/// way to one branch and already past to the other, and a pass spanning
/// midnight could classify two trips against different days.
final homeTripChecklistProvider =
    FutureProvider<({Trip trip, int done, int total})?>((ref) async {
      final trips = await ref.watch(allTripsProvider.future);
      final now = DateTime.now();
      Trip? candidate;
      for (final trip in trips) {
        if (trip.containsDate(now)) {
          candidate = trip;
          break;
        }
        if (!trip.startsAfter(now)) continue;
        if (candidate == null || trip.startDate.isBefore(candidate.startDate)) {
          candidate = trip;
        }
      }
      if (candidate == null) return null;
      final progress = await ref.watch(
        tripChecklistProgressProvider(candidate.id).future,
      );
      if (progress.total == 0) return null;
      return (trip: candidate, done: progress.done, total: progress.total);
    });
