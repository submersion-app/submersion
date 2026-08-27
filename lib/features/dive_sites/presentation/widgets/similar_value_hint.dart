import 'package:flutter/material.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Inline hint shown beneath a name/search field when [query] closely matches
/// an existing value in [candidates].
///
/// When [onAccept] is non-null the hint is tappable ("tap to use") and reports
/// the matched value — used in the dive-entry site picker to select the
/// existing site. When null the hint is a passive warning — used on the site
/// create/edit form, where switching to another site is not possible.
class SimilarValueHint extends StatelessWidget {
  const SimilarValueHint({
    super.key,
    required this.query,
    required this.candidates,
    this.onAccept,
  });

  final String query;
  final List<String> candidates;
  final ValueChanged<String>? onAccept;

  @override
  Widget build(BuildContext context) {
    final match = findSimilar(query, candidates);
    if (match == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final text = onAccept != null
        ? context.l10n.diveSites_similarSite_useHint(match)
        : context.l10n.diveSites_similarSite_warning(match);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );

    if (onAccept == null) return content;
    return InkWell(onTap: () => onAccept!(match), child: content);
  }
}
