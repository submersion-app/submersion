import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_write_confirm_dialog.dart';

/// How long the diver has to answer before the agent is told no.
const kAgentWriteConfirmTimeout = Duration(minutes: 5);

/// Held here because the protocol builds a server per request, and a plan
/// from a preview must still be here at its apply.
final agentWritePlanStoreProvider = Provider<WritePlanStore>(
  (ref) => WritePlanStore(),
);

/// The table for each entity, for the dialog's wording.
final agentWriteConfirmerProvider =
    Provider.family<WriteConfirmer, Map<String, String>>(
      (ref, entityTables) => AppWriteConfirmer(
        context: () => rootNavigatorKey.currentContext,
        entityTables: entityTables,
      ),
    );

/// Shows [AgentWriteConfirmDialog] over whatever the diver is doing. One
/// request at a time, so a second agent call waits for the first answer.
class AppWriteConfirmer implements WriteConfirmer {
  AppWriteConfirmer({
    required BuildContext? Function() context,
    required Map<String, String> entityTables,
    Duration timeout = kAgentWriteConfirmTimeout,
    Future<void> Function()? raiseWindow,
  }) : _context = context,
       _entityTables = entityTables,
       _timeout = timeout,
       _raiseWindow = raiseWindow ?? _raiseAppWindow;

  static const _log = LoggerService('AgentAccess');

  final BuildContext? Function() _context;
  final Map<String, String> _entityTables;
  final Duration _timeout;
  final Future<void> Function() _raiseWindow;

  Future<void> _queue = Future.value();

  @override
  Future<bool> confirm(WriteConfirmation request) {
    final answer = _queue.then((_) => _ask(request));
    _queue = answer.then((_) {}, onError: (_) {});
    return answer;
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

Future<void> _raiseAppWindow() async {
  if (!hasDesktopWindow()) return;
  await windowManager.show();
  await windowManager.focus();
}
