import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Marks whether an underwater track is linked to a dive: a filled,
/// rounded-rect label (shape and theme-token colors from `PlannedDiveChip`)
/// instead of the outlined `Chip`/`ActionChip` this replaces. Tapping it
/// opens the linked dive; an unlinked row's label is not tappable.
class NavTrackLinkLabel extends StatelessWidget {
  const NavTrackLinkLabel({super.key, required this.label, this.diveId});

  final String label;

  /// Opens `/dives/$diveId` on tap when set; renders as a plain, inert
  /// label (neutral surface tone) when null.
  final String? diveId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diveId = this.diveId;
    final linked = diveId != null;
    final background = linked
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = linked
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final content = Container(
      key: const ValueKey('nav-track-link-label'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
    if (!linked) return content;
    // InkWell alone only attaches a tap action to its Semantics node, not a
    // button role -- the ActionChip this replaces (built on RawChip) set
    // Semantics(button: true) explicitly, so a screen reader announced it as
    // a button. Without this wrapper a screen-reader user hears only the
    // label text with a bare tap action, not "button".
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/dives/$diveId'),
        child: content,
      ),
    );
  }
}
