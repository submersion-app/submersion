import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_color_contrast.dart';

/// A tag shown in the colour the diver gave it (issue #2254).
///
/// Every tag chip in the app renders through this widget, so a tag looks the
/// same in a dive list row, on a detail card, beside a site and beside a
/// piece of equipment. The fill is [Tag.color] at full opacity, never a
/// translucent tint: a tint is not a colour but a recipe, and the chips that
/// used one resolved to a different colour on every surface, turning an amber
/// tag grey-olive on a selected row. The label takes the colour that
/// contrasts with the fill, since the palette spans a pale yellow and a
/// near-black slate.
class TagChip extends StatelessWidget {
  TagChip({
    super.key,
    required Tag tag,
    this.onTap,
    this.onDeleted,
    this.tooltip,
    this.deleteTooltip,
    this.dense = false,
  }) : name = tag.name,
       color = tag.color;

  /// A tag with no row of its own yet, such as one typed into the import
  /// wizard before the import runs.
  const TagChip.unsaved({
    super.key,
    required this.name,
    required this.color,
    this.onTap,
    this.onDeleted,
    this.tooltip,
    this.deleteTooltip,
    this.dense = false,
  });

  final String name;

  /// The fill, painted opaque. [Tag.color] for a stored tag.
  final Color color;

  /// Tapping the chip, usually to open what carries the tag.
  final VoidCallback? onTap;

  /// Removing the tag. The chip grows a close button when this is set.
  final VoidCallback? onDeleted;

  final String? tooltip;
  final String? deleteTooltip;

  /// The tighter type and padding for a list row, where several chips share
  /// a line under the dive's stats.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final foreground = tagForegroundColor(color);
    final borderRadius = BorderRadius.circular(dense ? 4 : 8);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: foreground,
      fontSize: dense ? 11 : null,
    );

    Widget chip = Material(
      color: color,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          // A removable chip drops its vertical padding and takes its height
          // from the close button's tap target instead, which is how a
          // Material chip with a delete button sizes itself. Padding on top
          // of a 48 dp target would make the chip 56 dp tall.
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 10,
            vertical: onDeleted != null
                ? 0
                : dense
                ? 2
                : 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDeleted != null) ...[
                const SizedBox(width: 4),
                _DeleteButton(
                  color: foreground,
                  // Material's own chips label their delete button from the
                  // same string, so a caller that has nothing better to say
                  // keeps the wording screen readers already know.
                  tooltip:
                      deleteTooltip ??
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: onDeleted!,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      chip = Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

/// The close button of a removable chip.
///
/// The tap target is measured, not assumed: a bare icon with a splash radius
/// leaves a 16 dp target, and `VisualDensity.compact` pulls an [IconButton]
/// below its own constraints floor. The icon stays chip sized while the
/// button is constrained to the platform's minimum.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  /// The floor for the tap target. A finger needs the 48 dp Material touch
  /// minimum; a pointer is precise, and a 48 dp box inside a chip is out of
  /// scale on a desktop, so it takes the 32 dp pointer minimum instead.
  static double targetFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => 48,
    TargetPlatform.macOS ||
    TargetPlatform.linux ||
    TargetPlatform.windows => 32,
  };

  @override
  Widget build(BuildContext context) {
    final target = targetFor(Theme.of(context).platform);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(Icons.close, size: 16, color: color),
      iconSize: 16,
      padding: EdgeInsets.zero,
      // shrinkWrap so the constraints alone decide the box: the padded
      // setting would add its own 48 dp on top of them.
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(target, target),
        maximumSize: Size(target, target),
      ),
      constraints: BoxConstraints(minWidth: target, minHeight: target),
    );
  }
}
