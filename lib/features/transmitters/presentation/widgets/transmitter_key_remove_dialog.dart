import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before one key of a Transmitter item is removed (issue #3676): the
/// item and its other keys stay. True when the diver confirms.
Future<bool> confirmRemoveTransmitterKey(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.transmitters_key_removeTitle),
      content: Text(dialogContext.l10n.transmitters_key_removeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.common_action_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.common_action_remove),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
