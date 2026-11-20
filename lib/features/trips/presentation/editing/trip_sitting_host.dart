import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

const _log = LoggerService('TripSittingHost');

/// Loads what a sitting on a trip holds besides its own values: who it is
/// shared with, the vessel, the itinerary days, the checklists, the packed
/// gear and cylinder board, and the document links.
void loadTripSitting(EditSession<Trip> session, ProviderContainer container) {
  // Read now: an owner's Save clears share rows a sync race left beside
  // the Everyone flag, as the form's did, whichever card it changed.
  loadTripSharing(session, container.read);
  tripVesselDetails(
    container.read(liveaboardDetailsRepositoryProvider),
  ).load(session);
  tripItineraryDays(
    container.read(itineraryDayRepositoryProvider),
  ).load(session);
  tripChecklistsList(
    checklists: container.read(tripChecklistsRepositoryProvider),
    items: container.read(tripChecklistRepositoryProvider),
  ).load(session);
  tripPackedGearList(
    read: (id) => container.read(tripGearProvider(id).future),
    packs: container.read(tripEquipmentRepositoryProvider),
  ).load(session);
  tripCylindersList(
    cylinders: container.read(tripCylinderRepositoryProvider),
    copier: container.read(tripFillPassportCopierProvider),
  ).load(session);
  holdDocumentLinks(
    session,
    container.read,
    owner: DocumentOwner(DocumentOwnerKind.trip, session.stored.id),
    cardId: TripCardId.documents.name,
  );
}

/// What a sitting on a trip loads and how it is saved, for every page that
/// holds one: the trip page and its cylinder board (issue #4527, phase 3).
/// The board opened alone saves exactly as the trip page does, as one
/// History entry on the trip.
mixin TripSittingHost<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, RecordEditHost<W, Trip> {
  @override
  String recordIdOf(Trip record) => record.id;

  @override
  Trip? get storedForUnlock => ref.read(tripByIdProvider(hostRecordId)).value;

  @override
  String editingTitle(Trip record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  @override
  void onSittingStart(EditSession<Trip> session, ProviderContainer container) =>
      loadTripSitting(session, container);

  /// The held write that assigns the dives the diver chose at Save.
  static const assignDivesKey = 'trip.assignDives';

  /// What that write assigns, for the notice and the old trips' pages once
  /// it has been written.
  ({int count, Set<String> oldTripIds})? _assigned;

  /// When the dates changed in the sitting, the dives in the new dates that
  /// are not on the trip are offered before anything is written, as the
  /// form offered them after its save. The ones chosen are assigned in the
  /// sitting's transaction, so Cancel or a failed Save assigns none and one
  /// History entry holds them. Asked once per Save: the answer replaces any
  /// earlier one, and dates put back drop it. Dismissing the question saves
  /// with no dives, as the form did.
  @override
  Future<bool> beforeSave() async {
    final session = maybeEditController?.session;
    if (session == null) return true;
    session.releaseWrite(assignDivesKey);
    _assigned = null;
    final stored = session.stored;
    final working = session.working;
    if (stored.startDate == working.startDate &&
        stored.endDate == working.endDate) {
      return true;
    }
    final trips = ref.read(tripRepositoryProvider);
    final List<DiveCandidate> candidates;
    try {
      // The profile may still be being read just after the page opened;
      // the form waited for it, and so does this.
      final diverId =
          ref.read(validatedCurrentDiverIdProvider).value ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null || !mounted || session.isDisposed) {
        return mounted && !session.isDisposed;
      }
      candidates = await trips.findCandidateDivesForTrip(
        tripId: stored.id,
        startDate: working.startDate,
        endDate: working.endDate,
        diverId: diverId,
      );
    } catch (e, stackTrace) {
      // The question is an offer: a read that fails asks nothing, and the
      // dates are saved as the diver set them.
      _log.error(
        'Failed to find the dives in trip ${stored.id}\'s new dates',
        error: e,
        stackTrace: stackTrace,
      );
      return mounted && !session.isDisposed;
    }
    if (!mounted || session.isDisposed) return false;
    if (candidates.isEmpty) return true;
    final chosen = await showDiveAssignmentDialog(
      context: context,
      candidates: candidates,
    );
    if (!mounted || session.isDisposed) return false;
    if (chosen == null || chosen.isEmpty) return true;
    final picked = chosen.toSet();
    _assigned = (
      count: chosen.length,
      oldTripIds: {
        for (final c in candidates)
          if (picked.contains(c.dive.id) && !c.isUnassigned) c.currentTripId!,
      },
    );
    session.holdWrite(
      assignDivesKey,
      () => trips.assignDivesToTrip(chosen, stored.id),
    );
    return true;
  }

  /// Writes the sitting through the trip's save service: its changed values
  /// and its held writes, in one transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Trip> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final assigned = session.isHeld(assignDivesKey) ? _assigned : null;
    final service = ref.read(tripEditSaveServiceProvider);
    // The profile acting now, which the update checks before it writes the
    // Everyone flag; the sitting never changes that flag on the row itself,
    // so a profile not yet read only keeps the stored one.
    final actingDiverId = ref.read(validatedCurrentDiverIdProvider).value;
    final result = await service.save(
      // The trip the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      tripId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      actingDiverId: actingDiverId,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
    if (assigned != null) {
      _assigned = null;
      // The dives' old trips count them no more.
      final tripId = session.stored.id;
      for (final id in {tripId, ...assigned.oldTripIds}) {
        container
          ..invalidate(tripWithStatsProvider(id))
          ..invalidate(diveIdsForTripProvider(id))
          ..invalidate(divesForTripProvider(id));
      }
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.trips_diveScan_added(assigned.count))),
      );
    }
  }

  @override
  Future<Trip?> rereadStored(ProviderContainer container, Trip stored) {
    container.invalidate(tripWithStatsProvider(stored.id));
    container.invalidate(tripByIdProvider(stored.id));
    return container.read(tripByIdProvider(stored.id).future);
  }
}
