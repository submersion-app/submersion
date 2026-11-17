import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_date_stretch_message.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('DiveSittingFollowUp');

/// Has what a dive's cylinders, gear, weights and header values feed worked out
/// again in the background: its derived metrics (gas use, SAC), the sensor
/// summary of its gear, and its data-quality findings (a reassign repairs one,
/// gear feeds the shared-gear finding, and times, depths and the site feed the
/// rest), after every save, as the old dive form did. A provider, so a test can
/// stand in for the schedulers.
final diveGearRefreshProvider = Provider<void Function(String diveId)>(
  (ref) => (diveId) {
    scheduleQualityScan([diveId]);
    scheduleDerivedMetricsRefresh([diveId]);
    scheduleSensorSummaryRefresh([diveId]);
  },
);

/// Records the tide for a saved dive at its site, when the site has
/// coordinates, after every save, as the old dive form did. A dive with no tide
/// to record (no site, one with no location, or fresh water) has its record
/// cleared instead: a tide record is worked out from the site, never typed, so
/// one left from a site the dive is no longer at would show a tide that never
/// was (issue #4527). A tide model that cannot answer leaves the record as it
/// is: it answers null for a fetch that failed with nothing cached, or a grid
/// this device has not got, as well as for a place it does not cover, and
/// cannot say which. A dive with no located site but a position of its own
/// keeps its record too: a draft's tide is recorded there
/// (`DraftConditionsService`), and nothing records it again.
///
/// The saves' calls are not waited for, and a record replaces the dive's
/// last one, so each dive's are run one after another, in the order the
/// saves asked: an older save whose tide model answers late never lands
/// over a newer one's. A provider, so a test can stand in for the tide
/// model.
final diveTideRecordProvider = Provider<Future<void> Function(Dive dive)>((
  ref,
) {
  final last = <String, Future<void>>{};
  return (dive) {
    final previous = last[dive.id] ?? Future<void>.value();
    // A failed earlier one has been reported to its own caller.
    final next = previous
        .then<void>((_) {}, onError: (_) {})
        .then((_) => _recordDiveTide(ref, dive));
    last[dive.id] = next;
    unawaited(
      next.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        if (identical(last[dive.id], next)) last.remove(dive.id);
      }),
    );
    return next;
  };
});

Future<void> _recordDiveTide(Ref ref, Dive dive) async {
  final repository = ref.read(tideRecordRepositoryProvider);
  final location = dive.site?.location;
  if (dive.effectiveWaterType == WaterType.fresh) {
    await repository.deleteTideRecordForDive(dive.id);
  } else if (location == null) {
    if (dive.entryLocation != null) return;
    await repository.deleteTideRecordForDive(dive.id);
  } else {
    final resolved = await ref.read(resolvedTideDataProvider(location).future);
    if (resolved == null) return;
    await recordDiveTide(
      repository: repository,
      calculator: resolved.calculator,
      diveId: dive.id,
      entryWallClock: dive.effectiveEntryTime,
      location: location,
      waterType: dive.effectiveWaterType,
    );
  }
  ref.invalidate(tideRecordForDiveProvider(dive.id));
}

/// Looks up the altitude of [point] for the site [siteId], which a saved
/// sitting has just given that location, and stores it while the site has
/// none, as the immediate path does once a site gains its location
/// (`SiteMatchingService.applyConfirmed`). A provider, so a test can stand
/// in for the network.
final diveSiteAltitudeFillProvider =
    Provider<Future<void> Function(String siteId, GeoPoint point)>(
      (ref) => (siteId, point) async {
        final meters = await ref
            .read(elevationServiceProvider)
            .fetchElevation(
              latitude: point.latitude,
              longitude: point.longitude,
            );
        if (meters == null) return;
        await ref
            .read(siteRepositoryProvider)
            .fillSiteAltitudeIfEmpty(siteId, meters);
      },
    );

/// Tells the planner a plan's dive link changed outside it (issue #4003),
/// so a plan open there does not put the old link back. A provider, so a
/// test can stand in for the planner.
final divePlanLinkAdoptProvider =
    Provider<void Function(String planId, String? diveId)>(
      (ref) =>
          (planId, diveId) => ref
              .read(divePlanNotifierProvider.notifier)
              .adoptLink(planId, diveId),
    );

/// The cards whose values feed the background refresh
/// ([diveGearRefreshProvider]): the header's times, depths and site as well
/// as the gear (issue #4527).
final _refreshedByCardIds = {
  diveHeaderCardId,
  DiveDetailSectionId.tanks.name,
  DiveDetailSectionId.equipment.name,
  DiveDetailSectionId.weights.name,
};

/// Whether the tide recorded for a dive saved as [before] may no longer be
/// the one for [after]: what it is worked out from moved.
bool _tideInputsMoved(Dive before, Dive after) =>
    before.site?.id != after.site?.id ||
    before.site?.location != after.site?.location ||
    before.effectiveEntryTime != after.effectiveEntryTime ||
    before.effectiveWaterType != after.effectiveWaterType;

/// What a saved editing sitting on a dive still owes once its write has
/// gone through: a word about a trip whose dates it moved, a fresh read of
/// the courses it changed, the visibility input to offer next time, a
/// fresh read of what the sites it moved the dive between have seen, the
/// dive's tide when its site, time or water type moved, and the altitude of
/// a site it gave a location.
///
/// Made before the write, because everything it needs comes from the page
/// and the write can finish after the page has gone.
///
/// By the time [run] is called the sitting is committed. Each step is
/// therefore on its own: one that fails is logged and the rest still run,
/// and none of it can make a save that went through read as one that
/// failed.
class DiveSittingFollowUp {
  DiveSittingFollowUp.read(BuildContext context, WidgetRef ref)
    : _messenger = ScaffoldMessenger.of(context),
      _l10n = context.l10n,
      _units = ref.read(unitFormatterProvider),
      _mode = _modeOrNull(ref),
      _gearRefresh = ref.read(diveGearRefreshProvider),
      _recordTide = ref.read(diveTideRecordProvider),
      _fillSiteAltitude = ref.read(diveSiteAltitudeFillProvider),
      _adoptPlanLink = ref.read(divePlanLinkAdoptProvider),
      _container = ProviderScope.containerOf(context, listen: false);

  final ScaffoldMessengerState _messenger;
  final AppLocalizations _l10n;
  final UnitFormatter _units;

  /// Null when it cannot be had on this device: remembering the input is a
  /// convenience, and must never stop the save it follows.
  final VisibilityInputModeNotifier? _mode;

  static VisibilityInputModeNotifier? _modeOrNull(WidgetRef ref) {
    try {
      return ref.read(visibilityInputModeProvider.notifier);
    } catch (error, stackTrace) {
      _log.warning(
        'The visibility input mode cannot be remembered on this device',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  final ProviderContainer _container;
  final void Function(String diveId) _gearRefresh;
  final Future<void> Function(Dive dive) _recordTide;
  final Future<void> Function(String siteId, GeoPoint point) _fillSiteAltitude;
  final void Function(String planId, String? diveId) _adoptPlanLink;

  /// [before] and [after] are the dive as the save found it and as it left
  /// it; [tripDateStretches] the trips whose dates it moved;
  /// [changedCardIds] the cards the sitting changed. The rest come from the
  /// sitting's own writes: [mediaAfterCommit] the uploads its media queue,
  /// [buddyIds] the buddies it had before and after, [skippedRouteIds] the
  /// routes it could not link, [planLinksAdopted] the plan links it moved.
  Future<void> run({
    required Dive before,
    required Dive after,
    required List<TripDateStretch> tripDateStretches,
    required Set<String> changedCardIds,
    required List<Future<void> Function()> mediaAfterCommit,
    Set<String> buddyIds = const {},
    List<String> skippedRouteIds = const [],
    List<(String, String?)> planLinksAdopted = const [],
    Map<String, GeoPoint> sitesLocated = const {},
  }) async {
    await _guarded(
      'name the stretched trip',
      after,
      () => _sayTripMoved(tripDateStretches),
    );
    await _guarded(
      'refresh the courses',
      after,
      () => _refreshCourses(before, after),
    );
    await _guarded(
      'remember the visibility input',
      after,
      () => _rememberVisibilityInput(before, after),
    );
    await _guarded(
      'refresh the species of its sites',
      after,
      () => _refreshSiteSpecies(before, after),
    );
    // Gas switches and the readings moved by a reassign change no dive
    // value, so this is asked of the cards, not of before and after.
    if (changedCardIds.any(_refreshedByCardIds.contains)) {
      await _guarded(
        'refresh what its header, cylinders, gear and weights feed',
        after,
        () => _gearRefresh(after.id),
      );
    }
    // The dive form records the tide on every save. Here it is recorded
    // again when the site, the entry time or the water type moved, the
    // values it is worked out from, or the save gave the site its location:
    // [after] is the sitting's copy, whose site does not have that location
    // yet. Not waited for: working the tide out can take a while, and the
    // save has already gone through.
    final site = after.site;
    final located = site == null ? null : sitesLocated[site.id];
    final tideDive = located == null
        ? after
        : after.copyWith(site: site!.copyWith(location: located));
    if (located != null || _tideInputsMoved(before, after)) {
      unawaited(
        _guarded('record its tide', after, () => _recordTide(tideDive)),
      );
    }
    // A location the sitting held for a site is written now, so its
    // altitude is looked up as the immediate path does: after the commit,
    // so the network never holds the save's transaction, and not waited
    // for (issue #4527). [sitesLocated] is what the held writes noted.
    for (final MapEntry(key: siteId, value: point) in sitesLocated.entries) {
      unawaited(
        _guarded(
          "look up its site's altitude",
          after,
          () => _fillSiteAltitude(siteId, point),
        ),
      );
    }
    await _refreshCards(
      before,
      after,
      changedCardIds,
      mediaAfterCommit: mediaAfterCommit,
      buddyIds: buddyIds,
      skippedRouteIds: skippedRouteIds,
      planLinksAdopted: planLinksAdopted,
    );
  }

  /// Reads again what the cards with rows of their own show, for the cards
  /// the sitting changed only, as the dive form does after its save.
  Future<void> _refreshCards(
    Dive before,
    Dive after,
    Set<String> changed, {
    required List<Future<void> Function()> mediaAfterCommit,
    required Set<String> buddyIds,
    required List<String> skippedRouteIds,
    required List<(String, String?)> planLinksAdopted,
  }) async {
    final id = after.id;
    final c = _container;
    bool did(DiveDetailSectionId card) => changed.contains(card.name);
    if (did(DiveDetailSectionId.buddies)) {
      await _guarded('refresh its buddies', after, () {
        c.invalidate(buddiesForDiveProvider(id));
        for (final buddyId in buddyIds) {
          c.invalidate(buddyStatsProvider(buddyId));
          c.invalidate(diveIdsForBuddyProvider(buddyId));
          c.invalidate(divesForBuddyProvider(buddyId));
        }
        c.invalidate(allBuddiesWithDiveCountProvider);
      });
    }
    if (did(DiveDetailSectionId.sightings)) {
      await _guarded('refresh its sightings', after, () {
        c.invalidate(diveSightingsProvider(id));
        for (final siteId in {?before.site?.id, ?after.site?.id}) {
          c.invalidate(siteSpottedSpeciesProvider(siteId));
        }
      });
    }
    if (did(DiveDetailSectionId.profile) || did(DiveDetailSectionId.notes)) {
      await _guarded(
        'refresh its annotations',
        after,
        () => c.invalidate(diveAnnotationsProvider(id)),
      );
    }
    if (did(DiveDetailSectionId.signatures) ||
        did(DiveDetailSectionId.buddies)) {
      await _guarded('refresh its signatures', after, () {
        c.invalidate(signatureForDiveProvider(id));
        c.invalidate(buddySignaturesForDiveProvider(id));
      });
    }
    if (did(DiveDetailSectionId.safetyReview)) {
      await _guarded(
        'refresh its safety review',
        after,
        () => c.invalidate(safetyReviewProvider(id)),
      );
    }
    if (did(DiveDetailSectionId.navTrack)) {
      await _guarded('refresh its routes', after, () {
        // As the form: a route linked elsewhere or deleted meanwhile is
        // left out, and noted.
        if (skippedRouteIds.isNotEmpty) {
          _log.warning(
            'Routes not linked (linked elsewhere or deleted meanwhile): '
            '$skippedRouteIds',
          );
        }
        c.invalidate(navTracksForDiveProvider(id));
      });
    }
    if (did(DiveDetailSectionId.diveLab)) {
      await _guarded('hand the planner its plan links', after, () {
        for (final (planId, diveId) in planLinksAdopted) {
          _adoptPlanLink(planId, diveId);
        }
        c.invalidate(linkedPlanComparisonProvider(id));
      });
    }
    if (did(DiveDetailSectionId.documents)) {
      await _guarded(
        'refresh its documents',
        after,
        () => c.invalidate(
          documentsForOwnerProvider(DocumentOwner(DocumentOwnerKind.dive, id)),
        ),
      );
    }
    if (did(DiveDetailSectionId.media)) {
      // Each upload on its own: one that cannot be queued leaves the rest.
      for (final step in mediaAfterCommit) {
        await _guarded('queue an upload of its media', after, step);
      }
      await _guarded('refresh its media', after, () {
        c.invalidate(mediaForDiveProvider(id));
        c.invalidate(mediaCountForDiveProvider(id));
        c.invalidate(divePhotoGpsProvider(id));
        c.invalidate(allDivePhotoGpsProvider(id));
      });
    }
  }

  /// Runs one step. A step that fails is logged, with the dive it was for,
  /// and the next one still runs.
  Future<void> _guarded(
    String what,
    Dive dive,
    FutureOr<void> Function() step,
  ) async {
    try {
      await step();
    } catch (error, stackTrace) {
      _log.error(
        'After saving dive ${dive.id}, could not $what',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A dive put on a trip, or moved to another day on one, stretched that
  /// trip to cover it (#3351). The diver is told which, and its new dates.
  void _sayTripMoved(List<TripDateStretch> stretches) {
    final message = tripDateStretchMessage(_l10n, _units, stretches);
    if (message == null) return;
    _messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Every course the dive joined or left counts its dives again (#2515).
  void _refreshCourses(Dive before, Dive after) {
    final was = before.courseIds.toSet();
    final now = after.courseIds.toSet();
    if (setEquals(was, now)) return;
    _container.invalidate(coursesForDiveProvider(after.id));
    for (final courseId in was.union(now)) {
      _container.invalidate(courseDivesProvider(courseId));
      _container.invalidate(courseDiveCountProvider(courseId));
    }
  }

  /// A dive moved from one site to another changes what each has seen.
  void _refreshSiteSpecies(Dive before, Dive after) {
    final was = before.site?.id;
    final now = after.site?.id;
    if (was == now) return;
    for (final siteId in [?was, ?now]) {
      _container.invalidate(siteSpottedSpeciesProvider(siteId));
    }
  }

  /// The next new dive opens with the input this visibility was entered
  /// in (#3226). Only a new value counts, never one carried through.
  Future<void> _rememberVisibilityInput(Dive before, Dive after) async {
    final remembering = _mode;
    if (remembering == null) return;
    final saved = StoredVisibility.of(after);
    if (saved == StoredVisibility.of(before)) return;
    final mode = saved.modeToRemember;
    if (mode == null) return;
    await remembering.remember(mode);
  }
}
