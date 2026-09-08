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
/// Trips are ranked by how present they are -- one already under way first,
/// then the rest by how soon they start -- and the first with anything on its
/// list wins. Ranking and emptiness are separate filters on purpose: picking
/// the date-best trip and only then checking it for items would return null
/// whenever the nearest trip happened to be empty, hiding a perfectly good
/// checklist one trip along.
///
/// Both date tests read the one captured `now` through the entity's date-only
/// helpers. `Trip.isInProgress` would re-read `DateTime.now()` per trip, and
/// pairing it with an instant comparison on `startDate` mixed two clocks and
/// two granularities in a single pass: a trip starting today read as under
/// way to one branch and already past to the other, and a pass spanning
/// midnight could classify two trips against different days.
final homeTripChecklistProvider =
    FutureProvider<({Trip trip, int done, int total})?>((ref) async {
      final trips = await ref.watch(allTripsProvider.future);
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());

      final now = DateTime.now();
      final ranked =
          [
            for (final trip in trips)
              if (trip.containsDate(now) || trip.startsAfter(now)) trip,
          ]..sort((a, b) {
            final aRunning = a.containsDate(now);
            if (aRunning != b.containsDate(now)) return aRunning ? -1 : 1;
            return a.startDate.compareTo(b.startDate);
          });
      if (ranked.isEmpty) return null;

      // One query for the whole shortlist: the answer may be any of them, and
      // asking per trip would fan out a query and a table subscription each.
      final progress = await repository.getProgressForTrips([
        for (final trip in ranked) trip.id,
      ]);
      for (final trip in ranked) {
        final counts = progress[trip.id];
        if (counts == null || counts.total == 0) continue;
        return (trip: trip, done: counts.done, total: counts.total);
      }
      return null;
    });
