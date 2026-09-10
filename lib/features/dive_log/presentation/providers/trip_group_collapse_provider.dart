import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Base preference key holding the ids of trips folded shut in the dive list.
///
/// Device-local on purpose. Which trips a diver has tidied away is browsing
/// state, not logbook data, so it stays out of the synced settings row rather
/// than pushing an ever-growing id blob through sync (issue #1193).
const String kCollapsedTripIdsPrefsKey = 'dive_list_collapsed_trip_ids';

/// The storage key for [diverId]'s collapsed trips.
///
/// Scoped per diver: trips belong to a diver, and on a shared device one
/// diver folding a trip away must not fold it for the next. The unsuffixed
/// key is kept for the no-active-diver case rather than inventing a second
/// shape for it.
String collapsedTripIdsPrefsKeyFor(String? diverId) => diverId == null
    ? kCollapsedTripIdsPrefsKey
    : '$kCollapsedTripIdsPrefsKey:$diverId';

/// Trips folded shut in the dive list, persisted across restarts.
class CollapsedTripsNotifier extends StateNotifier<Set<String>> {
  static final _log = LoggerService.forClass(CollapsedTripsNotifier);

  CollapsedTripsNotifier(this._prefs, this._diverId)
    : super(
        _prefs.getStringList(collapsedTripIdsPrefsKeyFor(_diverId))?.toSet() ??
            {},
      );

  final SharedPreferences _prefs;
  final String? _diverId;

  String get _key => collapsedTripIdsPrefsKeyFor(_diverId);

  /// Fold [tripId] shut, or open it again.
  void toggle(String tripId) {
    final next = Set<String>.from(state);
    if (!next.remove(tripId)) next.add(tripId);
    _write(next);
  }

  /// Open [tripId], if it is folded shut.
  ///
  /// Used when navigation has to reveal a dive inside a collapsed trip. A real
  /// expansion rather than a render-time override, so the header's own
  /// collapse control still works afterwards.
  void expand(String tripId) {
    if (!state.contains(tripId)) return;
    _write(Set<String>.from(state)..remove(tripId));
  }

  /// Fold every trip in [tripIds] shut, keeping anything already collapsed.
  void collapseAll(Iterable<String> tripIds) => _write({...state, ...tripIds});

  /// Open every trip.
  void expandAll() => _write({});

  void _write(Set<String> next) {
    state = next;
    // Not awaited: every caller is a tap handler, and folding a trip must not
    // wait on disk. The in-memory set is the source of truth for the session,
    // so a failed write costs one forgotten fold, never data.
    //
    // The failure is swallowed explicitly rather than left on an unhandled
    // future, which would surface as an unhandled async error far away from
    // here with nothing naming the cause.
    unawaited(
      _prefs.setStringList(_key, next.toList()).then<void>((_) {}).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _log.warning(
          'Could not persist collapsed trips; they will reappear expanded '
          'on the next launch',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }
}

/// Trips the diver has folded shut in the dive list.
///
/// Watches the active diver, so switching profiles rebuilds the notifier
/// against that diver's own key rather than inheriting the previous one's
/// folded trips.
final collapsedTripIdsProvider =
    StateNotifierProvider<CollapsedTripsNotifier, Set<String>>((ref) {
      return CollapsedTripsNotifier(
        ref.watch(sharedPreferencesProvider),
        ref.watch(currentDiverIdProvider),
      );
    });
