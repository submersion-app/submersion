import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_date_stretch_message.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('DiveSittingFollowUp');

/// Has what a dive's cylinders, gear and weights feed worked out again in
/// the background: its derived metrics (gas use, SAC), the sensor summary
/// of its gear, and its data-quality findings (a reassign repairs one, and
/// gear feeds the shared-gear finding), as the dive form does after every
/// save (`dive_edit_page.dart`, after `_saveDive`). A provider, so a test
/// can stand in for the schedulers.
final diveGearRefreshProvider = Provider<void Function(String diveId)>(
  (ref) => (diveId) {
    scheduleQualityScan([diveId]);
    scheduleDerivedMetricsRefresh([diveId]);
    scheduleSensorSummaryRefresh([diveId]);
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

/// The cards whose values feed the refresh above.
final _gearCardIds = {
  DiveDetailSectionId.tanks.name,
  DiveDetailSectionId.equipment.name,
  DiveDetailSectionId.weights.name,
};

/// What a saved editing sitting on a dive still owes once its write has
/// gone through: a word about a trip whose dates it moved, a fresh read of
/// the courses it changed, the visibility input to offer next time, and a
/// fresh read of what the sites it moved the dive between have seen.
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
    if (changedCardIds.any(_gearCardIds.contains)) {
      await _guarded(
        'refresh what its cylinders, gear and weights feed',
        after,
        () => _gearRefresh(after.id),
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
