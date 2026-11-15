import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_date_stretch_message.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('DiveSittingFollowUp');

/// What a saved editing sitting on a dive still owes once its write has
/// gone through: a word about a trip whose dates it moved, a fresh read of
/// the courses it changed, and the visibility input to offer next time.
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

  /// [before] and [after] are the dive as the save found it and as it left
  /// it; [tripDateStretches] the trips whose dates it moved.
  Future<void> run({
    required Dive before,
    required Dive after,
    required List<TripDateStretch> tripDateStretches,
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
