import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The small outlined "Not verified" mark beside a built-in site gathered
/// from published sources.
///
/// Neutral, not a warning: it tells the diver where the record came from,
/// and the sentence beside it ([notVerifiedExplanation]) says what to do.
/// Its text is read by a screen reader with the row it sits in.
class NotVerifiedLabel extends StatelessWidget {
  const NotVerifiedLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          context.l10n.diveSites_catalogue_notVerified,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The sentence that explains the mark, where a surface has room for it.
String notVerifiedExplanation(BuildContext context) =>
    context.l10n.diveSites_catalogue_notVerifiedExplanation;
