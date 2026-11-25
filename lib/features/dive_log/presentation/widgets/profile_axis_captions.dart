import 'package:flutter/material.dart';

/// The unit captions above the profile chart's tick columns: the depth unit
/// over the left ticks, and the right axis's unit over the right ticks.
///
/// They stand in for the rotated axis titles, whose 16 px strips beside the
/// plot cost it width on every screen and most on a phone (issue #5013).
class ProfileAxisCaptions extends StatelessWidget {
  const ProfileAxisCaptions({
    super.key,
    required this.leftCaption,
    this.rightCaption,
    this.rightColor,
    this.onRightTap,
  });

  static const leftKey = ValueKey<String>('profileAxisCaption_left');
  static const rightKey = ValueKey<String>('profileAxisCaption_right');

  /// The depth unit, e.g. "m".
  final String leftCaption;

  /// The right axis's unit, or null while the right axis shows nothing.
  final String? rightCaption;

  /// The right axis's colour, so the caption reads as part of that axis.
  final Color? rightColor;

  /// Opens the right-axis metric picker, as a tap on the axis does.
  final VoidCallback? onRightTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final right = rightCaption;
    Widget? rightText;
    if (right != null) {
      rightText = Text(
        right,
        key: rightKey,
        style: style?.copyWith(color: rightColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      if (onRightTap case final onTap?) {
        rightText = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: rightText,
          ),
        );
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            leftCaption,
            key: leftKey,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (rightText != null) Flexible(child: rightText),
      ],
    );
  }
}
