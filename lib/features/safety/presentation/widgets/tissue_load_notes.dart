import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the tissue card once every compartment is back in
/// equilibrium with the air at the surface (issue #4228). The card itself
/// stays visible, so the diver sees the bars standing at their surface level
/// markers rather than the tissue view simply disappearing.
class TissueClearNote extends StatelessWidget {
  const TissueClearNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.check_circle_outline, color: colorScheme.primary),
        title: Text(l10n.safetyHub_tissueLoading_clear_title),
        subtitle: Text(l10n.safetyHub_tissueLoading_clear_body),
      ),
    );
  }
}

/// Shown in place of the tissue card when the last dive carries no tissue
/// data (gauge mode, a rebreather dive without a setpoint, no profile), so
/// the page says why there is nothing to show instead of leaving a gap.
class TissueUnavailableNote extends StatelessWidget {
  const TissueUnavailableNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
        title: Text(l10n.safetyHub_tissueLoading_unavailable_title),
        subtitle: Text(l10n.safetyHub_tissueLoading_unavailable_body),
      ),
    );
  }
}
