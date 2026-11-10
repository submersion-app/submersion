import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asked when the recording stops while a draft is open (issue #637): the
/// app never invents an exit time on its own. True marks the dive surfaced
/// now, false leaves it open, null cancels the stop.
Future<bool?> showSurfaceOnStopDialog(
  BuildContext context, {
  required DateTime entryTime,
}) {
  final time = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(unitFormatterProvider).formatTime(entryTime);
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.gpsLogger_surfaceOnStop_title),
        content: Text(l10n.gpsLogger_surfaceOnStop_body(time)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.gpsLogger_surfaceOnStop_leaveOpen),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.gpsLogger_surfaceOnStop_surfaceNow),
          ),
        ],
      );
    },
  );
}
