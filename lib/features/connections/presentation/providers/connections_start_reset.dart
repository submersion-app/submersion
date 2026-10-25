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

/// Moves this device onto the starting view once: the remembered map
/// becomes Who dives where and the Map layout and view return to the web
/// graph. Around mode's settings and the other display options are kept.
///
/// Runs before the view and display are restored. The writes are not
/// awaited: SharedPreferences updates its cache at once, so a restore
/// right after reads the new values. A failed write is logged; the worst
/// case is the move running again on the next launch.
void resetConnectionsStartOnce(SharedPreferences prefs) {
  if (prefs.getBool(kConnectionsStartResetKey) == true) return;
  if (prefs.containsKey(kConnectionsViewKey) ||
      prefs.containsKey(kConnectionsLegacyLensKey)) {
    final view = ConnectionsViewNotifier.restore(prefs).toStart();
    _write(prefs.setString(kConnectionsViewKey, jsonEncode(view.toJson())));
  }
  if (prefs.containsKey(kConnectionsDisplayKey)) {
    final display = ConnectionsDisplayNotifier.restore(prefs).copyWith(
      view: ConnectionsViewKind.graph,
      mapLayout: ConnectionsLayout.web,
    );
    _write(
      prefs.setString(kConnectionsDisplayKey, jsonEncode(display.toJson())),
    );
  }
  _write(prefs.setBool(kConnectionsStartResetKey, true));
}

void _write(Future<bool> write) {
  write.catchError((Object e, StackTrace st) {
    _log.warning(
      'Could not move Connections to its starting view',
      error: e,
      stackTrace: st,
    );
    return false;
  });
}
