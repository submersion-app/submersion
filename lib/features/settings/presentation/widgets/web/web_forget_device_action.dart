import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/web/web_forget_device_service.dart';
import 'package:submersion/features/settings/presentation/providers/web_forget_device_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Forget this device behind its confirmation (issues #4121, #4187): the
/// Sync page's row and Settings > Data's both run it. A forget that leaves
/// something behind says so rather than reloading over it.
Future<void> confirmAndForgetDevice(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.web_forgetDevice_title),
      content: Text(l10n.web_forgetDevice_confirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.web_forgetDevice_confirm),
        ),
      ],
    ),
  );
  // The page that asked may have gone while the question was open, and its
  // ref with it.
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(webForgetDeviceProvider)();
  } on WebForgetIncompleteException {
    // The sign-in details or settings survived: no reload over them.
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.web_forgetDevice_incomplete)));
  } catch (_) {
    // The database survived: say so rather than reload over it.
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.web_forgetDevice_failed)));
  }
}
