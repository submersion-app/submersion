import 'package:flutter/material.dart';

import 'package:submersion/core/theme/record_pencil_colors.dart';

/// How a [RecordEditAction] is drawn.
enum RecordEditActionStyle {
  /// The pencil's fill, glyph colour and ring: the bar's main way out
  /// (Save, Send, a satellite's Done).
  filled,

  /// The pencil's ring around a transparent ground, the label in the ring's
  /// colour: the way out that drops the edit (Cancel).
  ring,
}

/// A way out of an unlocked record (Cancel, Save, Done), drawn in the
/// pencil's [RecordPencilColors] so the way out is as easy to find as the
/// pencil that was the way in (issue #5034).
///
/// The bars used `AppBarTextAction`, which pins its label to the app bar's
/// foreground. That kept it visible on every theme, but in the page's own
/// colours, so it blended into the tinted bar. These bring their own ground
/// and label colours, which read the same under every preset, the Tropical
/// and Console bars included (#736, #1231).
class RecordEditAction extends StatelessWidget {
  const RecordEditAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = RecordEditActionStyle.filled,
    this.busy = false,
  });

  final String label;

  /// Null disables the action; its colours fade to Material's disabled
  /// opacity.
  final VoidCallback? onPressed;

  final RecordEditActionStyle style;

  /// Swaps the label for a progress indicator in the label's colour, for a
  /// save in flight. [label] still names the action for assistive
  /// technology. A filled action keeps its full fill while busy, so saving
  /// does not look like having nothing to save.
  final bool busy;

  /// Material's disabled opacity for a button's colours.
  static const double _disabledOpacity = 0.38;

  @override
  Widget build(BuildContext context) {
    final colors = RecordPencilColors.of(context);
    final filled = style == RecordEditActionStyle.filled;
    final foreground = filled ? colors.onFill : colors.outline;
    Color faded(Color c) => c.withValues(alpha: _disabledOpacity);

    final side = WidgetStateProperty.resolveWith<BorderSide>(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled) && !busy
            ? faded(colors.outline)
            : colors.outline,
      ),
    );

    final child = busy
        ? Semantics(
            label: label,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
          )
        : Text(label);

    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.fill,
          foregroundColor: colors.onFill,
          disabledBackgroundColor: busy ? colors.fill : faded(colors.fill),
          disabledForegroundColor: busy ? colors.onFill : faded(colors.onFill),
          visualDensity: VisualDensity.compact,
          padding: _buttonPadding,
        ).copyWith(side: side),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.outline,
        disabledForegroundColor: faded(colors.outline),
        visualDensity: VisualDensity.compact,
        padding: _buttonPadding,
      ).copyWith(side: side),
      child: child,
    );
  }
}

/// Horizontal padding of Cancel and Save on the unlocked record's bar:
/// tighter than a button's default 24, so the pair stays compact beside the
/// record's title.
const EdgeInsets _buttonPadding = EdgeInsets.symmetric(horizontal: 14);
