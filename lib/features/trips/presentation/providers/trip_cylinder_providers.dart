import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/data/services/trip_fill_saver.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_labels.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

final tripCylinderRepositoryProvider = Provider<TripCylinderRepository>(
  (ref) => TripCylinderRepository(),
);

/// The slots of a trip in board order.
final tripCylindersProvider = FutureProvider.family<List<TripCylinder>, String>(
  (ref, tripId) async {
    final repository = ref.watch(tripCylinderRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
    return repository.getCylindersForTrip(tripId);
  },
);

/// Every slot of a trip with its derived state: the ledger and the linked
/// tanks folded by [foldCylinderState]. Two lean queries beyond the slots
/// themselves; no dive is hydrated. Refreshes on any write to the slots,
/// their ledger, dive tanks or dives.
final tripCylinderStatesProvider =
    FutureProvider.family<List<TripCylinderState>, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());

      final cylinders = await repository.getCylindersForTrip(tripId);
      if (cylinders.isEmpty) return const [];
      final events = await repository.getEventsForTrip(tripId);
      final uses = await repository.getTankUsesForTrip(tripId);
      return [
        for (final cylinder in cylinders)
          foldCylinderState(
            cylinder: cylinder,
            events: events[cylinder.id] ?? const [],
            uses: uses[cylinder.id] ?? const [],
          ),
      ];
    });

/// Writes the passport copy of a trip fill on an owned cylinder.
final tripFillPassportCopierProvider = Provider<TripFillPassportCopier>(
  (ref) => TripFillPassportCopier(),
);

/// Makes a fill saver for one fill sheet. A factory rather than one shared
/// saver: each open sheet remembers its own earlier attempts.
final tripFillSaverFactoryProvider = Provider<TripFillSaver Function()>(
  (ref) =>
      () => TripFillSaver(
        repository: ref.read(tripCylinderRepositoryProvider),
        copier: ref.read(tripFillPassportCopierProvider),
      ),
);

/// Every fill and adjustment on a trip, newest first, for the ledger.
/// Entries at the same time list the one recorded last first; fills saved
/// together follow the board; the id settles the rest, so the order never
/// depends on the query.
final tripCylinderLedgerProvider =
    FutureProvider.family<List<TripCylinderEvent>, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchLedgerChanges());
      final (bySlot, slots) = await (
        repository.getEventsForTrip(tripId),
        repository.getCylindersForTrip(tripId),
      ).wait;
      final board = {for (final (i, c) in slots.indexed) c.id: i};
      final events = [for (final list in bySlot.values) ...list]
        ..sort((a, b) {
          final byTime = b.occurredAt.compareTo(a.occurredAt);
          if (byTime != 0) return byTime;
          final byCreated = b.createdAt.compareTo(a.createdAt);
          if (byCreated != 0) return byCreated;
          // Fills saved together share both times: list them as the board.
          final byBoard = (board[a.tripCylinderId] ?? 0).compareTo(
            board[b.tripCylinderId] ?? 0,
          );
          return byBoard != 0 ? byBoard : b.id.compareTo(a.id);
        });
      return events;
    });

/// Each slot's label and the bottle it held at a dive's start, for the dive
/// detail page. Keyed by trip and instant; refetches when the trip's slots
/// or ledger change. Auto-disposed: every dive opened is a new key.
final tripCylinderLabelsAtProvider = FutureProvider.autoDispose
    .family<
      Map<String, TripCylinderTankLabel>,
      ({String tripId, int atMillis})
    >((ref, key) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchLedgerChanges());
      final (cylinders, events) = await (
        repository.getCylindersForTrip(key.tripId),
        repository.getEventsForTrip(key.tripId),
      ).wait;
      return tripCylinderLabelsAt(
        cylinders: cylinders,
        eventsBySlot: events,
        atMillis: key.atMillis,
      );
    });

/// The trip's slots as they stood when a dive started, for the dive
/// editor's picker and suggestion: fills and adjustments up to that
/// instant, earlier dives, and never the dive being edited itself.
/// Auto-disposed: every date and time the editor tries is a new key.
final tripCylinderStatesAtProvider = FutureProvider.autoDispose
    .family<
      List<TripCylinderState>,
      ({String tripId, int atMillis, String? excludeDiveId})
    >((ref, key) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
      final (cylinders, events, uses) = await (
        repository.getCylindersForTrip(key.tripId),
        repository.getEventsForTrip(key.tripId),
        repository.getTankUsesForTrip(key.tripId),
      ).wait;
      return foldCylinderStatesAt(
        cylinders: cylinders,
        eventsBySlot: events,
        usesBySlot: uses,
        atMillis: key.atMillis,
        excludeDiveId: key.excludeDiveId,
      );
    });
