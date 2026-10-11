import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// A trailing action docked to a [FormOverline]: plain accent text button.
class FormOverlineAction {
  const FormOverlineAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Replaces [icon] with a small progress spinner (e.g. while fetching).
  final bool busy;
}

/// Sub-header inside a section body: uppercase letter-spaced overline with
/// optional accent text actions docked to its trailing edge. This is the
/// only sub-header style inside sections (spec: one subordinate style).
class FormOverline extends StatelessWidget {
  const FormOverline({
    super.key,
    required this.label,
    this.actions = const [],
    this.trailingText,
  });

  final String label;
  final List<FormOverlineAction> actions;

  /// Muted text docked before the actions (e.g. the weight total).
  final String? trailingText;

  /// The narrowest the label is squeezed to before the actions give up
  /// their text (issue #2652).
  static const double _minLabelWidth = 72;

  /// A labelled action's width: compact padding on both sides, the icon and
  /// its gap, then the text, never under the button's minimum width.
  static double _labelledWidth(
    FormOverlineAction action,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final text = painter.width;
    painter.dispose();
    final icon = action.icon != null || action.busy ? 16 + 8 : 0;
    final width = 16 + icon + text;
    return width < 56 ? 56 : width;
  }

  /// Whether every action, with its text, fits beside the label in
  /// [maxWidth]. When not, actions that have an icon show only the icon.
  bool _fits(BuildContext context, double maxWidth, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var used = _minLabelWidth;
    final trailing = trailingText;
    if (trailing != null) {
      final painter = TextPainter(
        text: TextSpan(text: trailing, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      used += painter.width + 8;
      painter.dispose();
    }
    for (final action in actions) {
      used += _labelledWidth(action, style, scaler, direction);
    }
    return used <= maxWidth;
  }

  Widget _icon(FormOverlineAction action) => action.busy
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : (action.icon != null
            ? Icon(action.icon, size: 16)
            : const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    final actionStyle = Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              actions.isNotEmpty &&
              !_fits(context, constraints.maxWidth, actionStyle);
          return Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: FormStyle.overlineStyle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(trailingText!, style: actionStyle),
                ),
              for (final action in actions)
                if (compact && (action.icon != null || action.busy))
                  IconButton(
                    tooltip: action.label,
                    onPressed: action.busy ? null : action.onPressed,
                    visualDensity: VisualDensity.compact,
                    color: Theme.of(context).colorScheme.primary,
                    icon: _icon(action),
                  )
                else
                  TextButton.icon(
                    onPressed: action.busy ? null : action.onPressed,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: actionStyle,
                    ),
                    icon: _icon(action),
                    label: Text(action.label),
                  ),
            ],
          );
        },
      ),
    );
  }
}
