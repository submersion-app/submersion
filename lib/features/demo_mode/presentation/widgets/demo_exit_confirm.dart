import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before leaving demo mode, since leaving discards every change made to
/// the sample logbook, then leaves on confirm.
Future<void> confirmAndExitDemo(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.demo_exit_confirm_title),
      content: Text(l10n.demo_exit_confirm_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.demo_exit_confirm_action),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(demoExitActionProvider)();
}
