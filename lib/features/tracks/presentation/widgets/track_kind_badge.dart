import 'package:flutter/material.dart';

import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "GPS" or "Underwater", so rows of both kinds read as one list.
///
/// Sits in the row's title line next to the title text (see
/// `GpsTrackListTile` / `NavTrackListRow`), so it follows [DiveTypeBadge]'s
/// shape -- a translucent-filled, bordered box sized to its own text --
/// rather than [DiveModeBadge]'s bare outline: that one exists for short,
/// fixed, deliberately unlocalized jargon (OC/CCR), while this badge's text
/// is a full localized word whose length varies by locale (French's
/// singular "Sous-marine", German's "Unterwasser", and so on), so it cannot
/// be abbreviated or given a fixed reserved width the way the mode badge is.
class TrackKindBadge extends StatelessWidget {
  TrackKindBadge(this.kind)
    : super(key: ValueKey('track-kind-badge-${kind.name}'));

  final TrackKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // Border and text share one color (`secondary`/`tertiary`, not the
    // `*Container`-paired `onSecondaryContainer`/`onTertiaryContainer`):
    // those "on" tokens are only guaranteed contrast against their matching
    // `*Container` fill, not against this badge's translucent `surface`
    // background -- the same reasoning `DiveTypeBadge` follows for its own
    // text color against the same kind of background.
    final (label, accent) = switch (kind) {
      TrackKind.gps => (l10n.tracks_kind_gps, scheme.secondary),
      TrackKind.underwater => (
        // Singular: one badge labels one track (the filter's label is plural).
        l10n.tracks_badge_underwater,
        scheme.tertiary,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.3),
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
