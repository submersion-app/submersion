import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The shell both species map info cards share: a title row with an open
/// button and a close button over a scrolling body capped at 45% of the
/// screen, so a rich site never covers the whole map.
class SpeciesMapCardFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onOpenTitle;
  final String openTooltip;
  final VoidCallback onClose;
  final List<Widget> children;

  const SpeciesMapCardFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.onOpenTitle,
    required this.openTooltip,
    required this.onClose,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.45;
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: openTooltip,
                    onPressed: onOpenTitle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.speciesMap_card_close,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
