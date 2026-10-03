import 'package:flutter/material.dart';

import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "GPS" or "Underwater", so rows of both kinds read as one list.
class TrackKindBadge extends StatelessWidget {
  TrackKindBadge(this.kind)
    : super(key: ValueKey('track-kind-badge-${kind.name}'));

  final TrackKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (kind) {
      TrackKind.gps => (
        l10n.tracks_kind_gps,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TrackKind.underwater => (
        // Singular: one badge labels one track (the filter's label is plural).
        l10n.tracks_badge_underwater,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
