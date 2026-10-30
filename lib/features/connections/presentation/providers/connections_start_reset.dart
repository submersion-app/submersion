import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';

/// Set once this device has been moved onto the simpler starting view
/// (issue #3679).
const kConnectionsStartResetKey = 'connections_start_reset_3679';

const _log = LoggerService('ConnectionsStartReset');

/// The move in flight per preferences store, so the view and display
/// providers building in one frame share one move instead of each writing.
final _inFlight = Expando<Future<void>>('connectionsStartReset');

/// Moves this device onto the starting view once: the remembered map
/// becomes Who dives where and the Map layout and view return to the web
/// graph. Around mode's settings and the other display options are kept.
///
/// Runs before the view and display are restored, and need not be awaited:
/// SharedPreferences updates its cache when a write is issued, which
/// happens before this first suspends, so a restore right after reads the
/// new values, and a later write from the page is issued (and lands) after
/// these. The marker is set only once both writes succeed; a failed one is
/// logged and the move runs again on the next launch.
Future<void> resetConnectionsStartOnce(
  SharedPreferences prefs, {
  Future<bool> Function(String key, String value)? writeString,
}) {
  if (prefs.getBool(kConnectionsStartResetKey) == true) return Future.value();
  final running = _inFlight[prefs];
  if (running != null) return running;
  final move = _move(prefs, writeString ?? prefs.setString);
  _inFlight[prefs] = move;
  return move.whenComplete(() => _inFlight[prefs] = null);
}

Future<void> _move(
  SharedPreferences prefs,
  Future<bool> Function(String key, String value) write,
) async {
  final writes = <Future<bool>>[];
  if (prefs.containsKey(kConnectionsViewKey) ||
      prefs.containsKey(kConnectionsLegacyLensKey)) {
    final view = ConnectionsViewNotifier.restore(prefs).toStart();
    writes.add(write(kConnectionsViewKey, jsonEncode(view.toJson())));
  }
  if (prefs.containsKey(kConnectionsDisplayKey)) {
    final display = ConnectionsDisplayNotifier.restore(prefs).copyWith(
      view: ConnectionsViewKind.graph,
      mapLayout: ConnectionsLayout.web,
    );
    writes.add(write(kConnectionsDisplayKey, jsonEncode(display.toJson())));
  }
  try {
    final written = await Future.wait(writes);
    if (written.every((ok) => ok)) {
      await prefs.setBool(kConnectionsStartResetKey, true);
    } else {
      _log.warning('Could not move Connections to its starting view');
    }
  } catch (e, st) {
    _log.warning(
      'Could not move Connections to its starting view',
      error: e,
      stackTrace: st,
    );
  }
}
