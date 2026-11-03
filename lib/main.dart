import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/app.dart';
import 'package:submersion/core/bootstrap/app_bootstrap.dart';
import 'package:submersion/core/bootstrap/bootstrap_shared.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overrides.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/shared/services/incoming_share.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

// main() is untestable startup wiring (it never runs under test); the
// zone-error logging is unit-tested via logUncaughtZoneError, and the
// platform bootstraps live under lib/core/bootstrap/.
// coverage:ignore-start
void main() {
  // Run startup inside a guarded zone so an uncaught async error during
  // initialization is logged instead of vanishing silently (issue #318
  // hardening: the app previously installed no global error capture at all).
  runZonedGuarded(bootstrapApp, logUncaughtZoneError);
}
// coverage:ignore-end

/// Global key notifier. Changing the value forces ProviderScope to rebuild,
/// disposing all providers and re-fetching from the current database.
final _restartKey = ValueNotifier<Key>(UniqueKey());

/// The share gate for the life of the process. A share still waiting for the
/// app to be able to open it (during setup, say) outlives the ProviderScope
/// that [restartApp] replaces, and the new app root opens it (#2690).
final _incomingShares = NavigationReadyGate<IncomingShare>();

/// Trigger a soft restart by rebuilding the entire ProviderScope.
/// Call this after a database restore to refresh all cached data.
void restartApp() {
  _restartKey.value = UniqueKey();
}

class SubmersionRestart extends StatelessWidget {
  final SharedPreferences prefs;
  final LogFileService logFileService;

  const SubmersionRestart({
    super.key,
    required this.prefs,
    required this.logFileService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Key>(
      valueListenable: _restartKey,
      builder: (context, key, _) {
        return ProviderScope(
          key: key,
          overrides: rootProviderOverrides(
            prefs: prefs,
            logFileService: logFileService,
            incomingShares: _incomingShares,
            proxyController: processProxyController,
          ).cast(),
          child: const SubmersionApp(),
        );
      },
    );
  }
}
