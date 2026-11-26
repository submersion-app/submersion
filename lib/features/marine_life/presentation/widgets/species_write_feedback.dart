import 'package:flutter/material.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('SpeciesWriteFeedback');

/// Runs [write] (a cover chosen, a practice answer) and, if it fails, tells
/// the diver instead of leaving an unhandled error (issue #5027). Returns
/// whether the write went through.
Future<bool> saveWithFeedback(
  BuildContext context,
  Future<void> Function() write,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = context.l10n.recordEdit_saveFailed;
  try {
    await write();
    return true;
  } catch (e, stackTrace) {
    _log.error('A species write failed', error: e, stackTrace: stackTrace);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}
