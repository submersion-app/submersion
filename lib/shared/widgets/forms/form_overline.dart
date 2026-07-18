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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
      child: Row(
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
              child: Text(
                trailingText!,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          for (final action in actions)
            TextButton.icon(
              onPressed: action.busy ? null : action.onPressed,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600),
              ),
              icon: action.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (action.icon != null
                        ? Icon(action.icon, size: 16)
                        : const SizedBox.shrink()),
              label: Text(action.label),
            ),
        ],
      ),
    );
  }
}
