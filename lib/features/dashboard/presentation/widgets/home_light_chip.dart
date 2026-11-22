import 'package:flutter/material.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart';

/// The height every pill can be tapped across, in the header and in the
/// sheet of every light: the 44-point minimum, though the pill is drawn
/// smaller.
const double homeLightMinHitHeight = 44;

/// One status light drawn as a pill: tinted by its tone, with its icon and
/// label, and tappable for its action.
class HomeLightChip extends StatelessWidget {
  final HomeStatusLight light;

  /// A smaller pill for the header bar; the full size for lists and sheets.
  final bool dense;

  const HomeLightChip(this.light, {this.dense = false, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final StatusSwatch? swatch = switch (light.tone) {
      HomeLightTone.alert => status.alert,
      HomeLightTone.warn => status.warn,
      HomeLightTone.ok => status.ok,
      HomeLightTone.neutral => null,
    };
    final (bg, fg, edge) = switch (swatch) {
      final s? => (s.container, s.onContainer, s.outline),
      // Neutral is a wash of the preset's own text colour rather than
      // surfaceContainerHighest: the hand-built presets leave that role
      // unset, so it resolved to the page colour and the pill vanished.
      null => (
        scheme.onSurface.withValues(alpha: 0.06),
        scheme.onSurfaceVariant,
        scheme.onSurface.withValues(alpha: 0.14),
      ),
    };
    final textStyle = dense
        ? Theme.of(context).textTheme.labelSmall
        : Theme.of(context).textTheme.labelMedium;
    final chip = InkWell(
      onTap: light.onTap,
      onLongPress: light.onLongPress,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        // One less than the inset each way: Container adds the 1px border
        // to its padding, so the outlined pill keeps its size.
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: edge),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(light.icon, size: dense ? 13 : 16, color: fg),
            SizedBox(width: dense ? 4 : 6),
            Flexible(
              child: Text(
                light.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
    // Drawn smaller than a finger, but tappable across 44 points of height:
    // a tap just above or below the pill still reaches it. On the pill
    // itself its own ink wins the tap.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: light.onTap,
      onLongPress: light.onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: homeLightMinHitHeight),
        child: Align(widthFactor: 1, heightFactor: 1, child: chip),
      ),
    );
  }
}
