import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/offer_site_review_after_import.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_dives_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_photos_sitting.dart';
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
  final vessel = tripVesselDetails(
    container.read(liveaboardDetailsRepositoryProvider),
  );
  if (session.isNew) {
    // A new trip (plan 11): nothing is stored under its id, and its page
    // shows no tab, so only its vessel starts, empty, besides its
    // documents.
    vessel.loadNone(session);
    _holdTripDocuments(session, container);
    return;
  }
  vessel.load(session);
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
  holdTripPhotos(session, container.read);
  _holdTripDocuments(session, container);
}

void _holdTripDocuments(
  EditSession<Trip> session,
  ProviderContainer container,
) => holdDocumentLinks(
  session,
  container.read,
  owner: DocumentOwner(DocumentOwnerKind.trip, session.stored.id),
  cardId: TripCardId.documents.name,
);

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
    final stored = session.stored;
    final working = session.working;
    return askDivesInDates(
      session,
      ask:
          stored.startDate != working.startDate ||
          stored.endDate != working.endDate,
    );
  }

  /// The dives the question at Save chose for [session]'s trip while their
  /// write is held: how many, and the trips they leave.
  ({int count, Set<String> oldTripIds})? divesChosenAtSave(
    EditSession<Trip> session,
  ) => session.isHeld(assignDivesKey) ? _assigned : null;

  /// Drops an earlier answer, then, when [ask], offers the dives in the
  /// trip's working dates that are not on it, and holds the ones chosen
  /// for the sitting's write. A new trip asks whatever its dates (plan 11,
  /// as the form asked after every create), for the diver it is created
  /// for ([diverId]); otherwise the dives are the active diver's. False
  /// when the page went meanwhile.
  Future<bool> askDivesInDates(
    EditSession<Trip> session, {
    bool ask = true,
    String? diverId,
  }) async {
    session.releaseWrite(assignDivesKey);
    _assigned = null;
    if (!ask) return true;
    final stored = session.stored;
    final working = session.working;
    final trips = ref.read(tripRepositoryProvider);
    final List<DiveCandidate> found;
    try {
      // The profile may still be being read just after the page opened;
      // the form waited for it, and so does this.
      final forDiver =
          diverId ??
          ref.read(validatedCurrentDiverIdProvider).value ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      if (forDiver == null || !mounted || session.isDisposed) {
        return mounted && !session.isDisposed;
      }
      found = await trips.findCandidateDivesForTrip(
        tripId: stored.id,
        startDate: working.startDate,
        endDate: working.endDate,
        diverId: forDiver,
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
    // Dives the Dives card's scan holds are assigned already (plan 10, Call
    // 9): never offered twice.
    final scanned = {for (final d in scannedDivesOf(session).dives) d.id};
    final candidates = [
      for (final c in found)
        if (!scanned.contains(c.dive.id)) c,
    ];
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
    final asked = divesChosenAtSave(session);
    final scanned = scannedDivesOf(session);
    final assigned = asked == null && scanned.dives.isEmpty
        ? null
        : (
            count: (asked?.count ?? 0) + scanned.dives.length,
            oldTripIds: {...?asked?.oldTripIds, ...scanned.oldTripIds},
          );
    // The dives the sitting's photos go to: once they are linked, the site
    // review the menu's photo scan offers is offered for them.
    final photoDiveIds = {for (final p in heldTripPhotos(session)) ?p.diveId};
    final service = ref.read(tripEditSaveServiceProvider);
    // The profile acting now, which the update checks before it writes the
    // Everyone flag; the sitting never changes that flag on the row itself,
    // so a profile not yet read only keeps the stored one.
    final actingDiverId = ref.read(validatedCurrentDiverIdProvider).value;
    // A failed write takes back what the photos' write did outside the
    // database.
    final result = await undoMediaOnFailure(
      session,
      () => service.save(
        // The trip the sitting was opened on, whatever the page shows by
        // the time the write is asked for.
        tripId: session.stored.id,
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        actingDiverId: actingDiverId,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      ),
    );
    justSavedRecord = result?.after ?? session.working;
    // The photos' uploads, once committed: each on its own, so one that
    // fails never reads as a failed save.
    for (final step in mediaAfterCommit(session)) {
      try {
        await step();
      } catch (e, stackTrace) {
        _log.error(
          'Photo follow-up after saving trip ${session.stored.id} failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
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
    if (photoDiveIds.isNotEmpty && mounted) {
      // Best effort, as after the menu's scan: nothing it does fails the
      // Save, and the page does not wait for it to lock.
      unawaited(
        offerSiteReviewAfterImport(
          context,
          ref,
          photoDiveIds,
          messenger: messenger,
        ),
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
