import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';

/// Marks whether an underwater track is linked to a dive, drawn with
/// [TagChip] -- the same chip a dive's own tags render with (including the
/// auto-generated "{source} Import {date}" tag on an imported dive), so a
/// track's link reads as the same kind of label a diver already recognizes
/// from the dive list, not a bespoke pill of its own. Tapping it opens the
/// linked dive; an unlinked row's label is not tappable.
class NavTrackLinkLabel extends StatelessWidget {
  const NavTrackLinkLabel({super.key, required this.label, this.diveId});

  final String label;

  /// Opens `/dives/$diveId` on tap when set; renders as a neutral,
  /// non-interactive chip when null.
  final String? diveId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diveId = this.diveId;
    final linked = diveId != null;
    // A real tag carries its own diver-chosen colour; this chip has no tag
    // behind it, so it borrows the theme's primary accent when linked (to
    // read the same way the primary-coloured import tag does) and a neutral
    // outline tone when not, rather than inventing a colour of its own.
    final color = linked ? scheme.primary : scheme.outline;
    return TagChip.unsaved(
      key: const ValueKey('nav-track-link-label'),
      name: label,
      color: color,
      dense: true,
      onTap: linked ? () => context.push('/dives/$diveId') : null,
    );
  }
}
