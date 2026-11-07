import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_write_confirm_dialog.dart';

/// How long the diver has to answer before the agent is told no.
const kAgentWriteConfirmTimeout = Duration(minutes: 5);

/// Held here because the protocol builds a server per request, and a plan
/// from a preview must still be here at its apply.
final agentWritePlanStoreProvider = Provider<WritePlanStore>(
  (ref) => WritePlanStore(),
);

/// One confirmer for the app, so it sees every request from every session.
final agentWriteConfirmerProvider = Provider<WriteConfirmer>(
  (ref) => AppWriteConfirmer(
    context: () => rootNavigatorKey.currentContext,
    entityTables: {
      for (final entry in WriteCatalog(RecordRepositories()).all)
        entry.name: entry.table,
    },
  ),
);

/// Shows [AgentWriteConfirmDialog] over whatever the diver is doing, one
/// request at a time. A second request is refused rather than queued: a
/// client that times out and retries would otherwise stack the same change
/// behind the first, and the diver would allow both.
class AppWriteConfirmer implements WriteConfirmer {
  AppWriteConfirmer({
    required BuildContext? Function() context,
    required Map<String, String> entityTables,
    Duration timeout = kAgentWriteConfirmTimeout,
    Future<void> Function()? raiseWindow,
  }) : _context = context,
       _entityTables = entityTables,
       _timeout = timeout,
       _raiseWindow = raiseWindow ?? raiseAppWindow;

  static const _log = LoggerService('AgentAccess');

  final BuildContext? Function() _context;
  final Map<String, String> _entityTables;
  final Duration _timeout;
  final Future<void> Function() _raiseWindow;

  bool _waiting = false;

  @override
  Future<bool> confirm(WriteConfirmation request) async {
    if (_waiting) {
      throw const AgentToolException(
        AgentToolErrorCode.confirmationPending,
        'The diver has not answered an earlier change yet, and this plan is '
        'used up. Once they have, read the records and call preview_changes '
        'again.',
      );
    }
    _waiting = true;
    try {
      return await _ask(request);
    } finally {
      _waiting = false;
    }
  }

  Future<bool> _ask(WriteConfirmation request) async {
    try {
      await _raiseWindow();
    } catch (error) {
      // The dialog still waits inside the window; the agent only waits longer.
      _log.warning('Could not raise the window: $error');
    }
    final context = _context();
    if (context == null || !context.mounted) return false;
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgentWriteConfirmDialog(
        request: request,
        entityTables: _entityTables,
      ),
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    // The route itself goes, so a dialog opened above it stays open.
    final timeout = Timer(_timeout, () {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
    try {
      return await navigator.push(route) ?? false;
    } finally {
      timeout.cancel();
    }
  }
}

/// Brings the app's window to the front so the diver sees the dialog.
@visibleForTesting
Future<void> raiseAppWindow() async {
  if (!hasDesktopWindow()) return;
  // The macOS plugin finds the window only here; a window call before it
  // unwraps nil in native code and the app quits (#4298).
  await windowManager.ensureInitialized();
  await windowManager.show();
  await windowManager.focus();
}
