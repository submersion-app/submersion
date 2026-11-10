import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/data/services/change_log_operation_undo.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_source_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('RemoveSourceFlow');

/// How long the removal's Undo stays offered.
const Duration _undoWindow = Duration(seconds: 10);

/// Remove source, as the dive's Data Sources menu and the data quality
/// inbox both run it (issue #4393): explain a source that cannot be removed,
/// confirm, remove, and offer one Undo for the whole change.
///
/// [afterChange] runs after the removal and again after its Undo (refresh
/// what shows the dive). [onRemoved] and [onUndone] are the caller's own
/// bookkeeping (the inbox resolves and reopens its finding); a failure in
/// either is logged and never reported as a failed removal, since by then
/// the removal or its Undo has landed. [undo] is replaceable for tests.
///
/// Every failure is reported here: callers drop the returned Future.
Future<void> removeSourceWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String diveId,
  required String sourceId,
  required String? sourceName,
  required VoidCallback afterChange,
  Future<void> Function()? onRemoved,
  Future<void> Function()? onUndone,
  Future<bool> Function(String operationId) undo = undoChangeLogOperation,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final removal = ref.read(diveSourceRemovalServiceProvider);

  Future<void> quietly(Future<void> Function()? hook, String what) async {
    if (hook == null) return;
    try {
      await hook();
    } catch (error, stackTrace) {
      _log.warning(what, error: error, stackTrace: stackTrace);
    }
  }

  try {
    // Two sources of one computer cannot be told apart, so the service
    // refuses them. The display can collapse such a pair into one card, so
    // the menu alone cannot hide the action: say why before confirming.
    if (await removal.sharesComputer(diveId: diveId, sourceId: sourceId)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLog_sources_removeSharedComputer)),
      );
      return;
    }
  } catch (error, stackTrace) {
    _log.warning(
      'Could not check source $sourceId',
      error: error,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_sources_removeFailed)),
    );
    return;
  }
  if (!context.mounted) return;
  if (!await confirmRemoveSource(context, source: sourceName)) return;

  final String? operationId;
  try {
    operationId = (await removal.remove(
      diveId: diveId,
      sourceId: sourceId,
    )).operationId;
  } catch (error, stackTrace) {
    _log.warning(
      'Could not remove source $sourceId',
      error: error,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_sources_removeFailed)),
    );
    return;
  }
  await quietly(onRemoved, 'After removing source $sourceId');
  afterChange();

  final undoable = operationId;
  messenger.showSnackBar(
    SnackBar(
      duration: _undoWindow,
      persist: false,
      content: Text(l10n.diveLog_sources_removeDone),
      action: undoable == null
          ? null
          : SnackBarAction(
              label: l10n.dataQuality_action_undo,
              onPressed: () => unawaited(() async {
                final whole = await undo(undoable);
                await quietly(onUndone, 'After undoing source $sourceId');
                afterChange();
                if (!whole) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.changeLog_undoIncomplete)),
                  );
                }
              }()),
            ),
    ),
  );
}
