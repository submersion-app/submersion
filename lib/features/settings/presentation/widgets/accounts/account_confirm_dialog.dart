import 'package:flutter/material.dart';

import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A confirmation naming the features [usages] lists, below [paragraphs]
/// and above [footer]. True only when the user picks [action].
Future<bool> confirmAccountAction(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  required List<AccountUsage> usages,
  required String action,
  String? footer,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, paragraph) in paragraphs.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: Text(paragraph),
              ),
            for (final usage in usages)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6),
                    const SizedBox(width: 8),
                    Expanded(child: Text(accountUsageName(l10n, usage))),
                  ],
                ),
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(footer),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
