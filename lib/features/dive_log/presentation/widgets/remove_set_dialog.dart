import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What to do with a set's gear when the set comes off a dive (issue
/// #4500).
enum RemoveSetChoice {
  /// The gear stays on the dive as gear of its own; only the set goes.
  keepGear,

  /// The gear the set brought goes with it.
  removeGear,
}

/// Asks whether removing a set from a dive takes its gear too. Keeping the
/// gear is the default answer, since it loses nothing. Null when dismissed.
Future<RemoveSetChoice?> showRemoveSetDialog(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<RemoveSetChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.diveLog_gear_removeSetTitle),
      content: Text(l10n.diveLog_gear_removeSetBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(RemoveSetChoice.removeGear),
          child: Text(l10n.diveLog_gear_removeSetRemoveGear),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(RemoveSetChoice.keepGear),
          child: Text(l10n.diveLog_gear_removeSetKeepGear),
        ),
      ],
    ),
  );
}
