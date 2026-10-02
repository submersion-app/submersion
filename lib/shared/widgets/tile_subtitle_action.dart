import 'package:flutter/material.dart';

/// A text action on its own line in a [ListTile] subtitle, lined up with the
/// subtitle text above it.
///
/// Text-bearing controls do not belong in [ListTile.trailing]: the tile lays
/// trailing out at its natural width before the title, so a translated label
/// there squeezes the title to one fragment per line on a phone (#935,
/// #2692, #2717). `test/architecture/list_tile_trailing_width_test.dart`
/// keeps them out; this is where a row's text action goes instead.
class TileSubtitleAction extends StatelessWidget {
  const TileSubtitleAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.actionKey,
  });

  final String label;

  /// Key for the button itself. A [ListTile] gives its subtitle the full
  /// line width, so this widget can be wider than its button; a key meant
  /// for a finder or a tap belongs on the button, not on this widget.
  final Key? actionKey;

  /// Null disables the action.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Start-aligned even when the parent forces the full line width, and
    // sized to the button when the parent allows it.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: TextButton(
        key: actionKey,
        // No horizontal padding, so the label starts where the subtitle text
        // does; compact so the extra line stays short.
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          alignment: AlignmentDirectional.centerStart,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
