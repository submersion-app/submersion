import 'package:flutter/material.dart';

import 'package:submersion/features/certification_agencies/domain/entities/certification_usage.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before deleting a custom agency or certification named [name].
Future<bool> confirmCertificationDelete(
  BuildContext context,
  String name,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.certificationAgencies_delete_confirmTitle(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Explains why a delete was refused (issue #690): the entry is still used,
/// and nothing is ever rewritten to make room for the delete.
Future<void> showCertificationDeleteRefusal(
  BuildContext context,
  CertificationUsage usage,
) {
  final l10n = context.l10n;
  final parts = [
    if (usage.certifications > 0)
      l10n.certificationAgencies_usage_certifications(usage.certifications),
    if (usage.courses > 0)
      l10n.certificationAgencies_usage_courses(usage.courses),
  ];
  final usageText = parts.length == 2
      ? l10n.certificationAgencies_usage_and(parts[0], parts[1])
      : parts.single;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.certificationAgencies_delete_refusedTitle),
      content: Text(l10n.certificationAgencies_delete_refusedBody(usageText)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.common_action_ok),
        ),
      ],
    ),
  );
}
