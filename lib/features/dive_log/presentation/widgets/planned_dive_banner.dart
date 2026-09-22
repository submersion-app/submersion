import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the header of a planned dive (issue #2002): awaiting dive
/// computer data, with the promote action for a dive made without one.
class PlannedDiveBanner extends StatelessWidget {
  final VoidCallback onMarkLogged;

  const PlannedDiveBanner({super.key, required this.onMarkLogged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.diveLog_planned_bannerTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    context.l10n.diveLog_planned_bannerBody,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onMarkLogged,
              child: Text(context.l10n.diveLog_detail_menu_markLogged),
            ),
          ],
        ),
      ),
    );
  }
}
