import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Dropdown list for a [RawAutocomplete] options overlay that honours the
/// keyboard.
///
/// [RawAutocomplete] already binds the arrow keys to its own intents and
/// tracks the highlighted option in [AutocompleteHighlightedOption]; an
/// options view that ignores that notifier leaves keyboard navigation
/// invisible and therefore unusable. This list reads it, paints the
/// highlighted row and keeps it scrolled into view, so arrow keys move a
/// visible selection and Enter commits it.
///
/// The field paired with this list must forward the `onFieldSubmitted`
/// callback that [RawAutocomplete] hands to its `fieldViewBuilder`:
/// `onFieldSubmitted: (_) => onFieldSubmitted()` on a [TextFormField], or
/// `onSubmitted: (_) => onFieldSubmitted()` on a [TextField]. Without it,
/// Enter has no way to commit the highlighted option.
class AutocompleteOptionsList<T extends Object> extends StatelessWidget {
  const AutocompleteOptionsList({
    super.key,
    required this.options,
    required this.onSelected,
    required this.labelFor,
    this.leadingFor,
    this.maxHeight = 200,
    this.dense = true,
  });

  /// Options as handed to `optionsViewBuilder`, in highlight order.
  final Iterable<T> options;

  /// Called with the chosen option, by tap or by keyboard.
  final AutocompleteOnSelected<T> onSelected;

  /// Display text for an option.
  final String Function(T option) labelFor;

  /// Optional leading widget (an icon, a colour swatch) per option.
  final Widget Function(BuildContext context, T option)? leadingFor;

  final double maxHeight;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    final theme = Theme.of(context);
    // optionsBuilder commonly returns a lazy Iterable; materialise it once so
    // indexing rows is not quadratic in the number of matches.
    final items = options.toList(growable: false);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        // Without a clip the rows' ink splashes paint past the rounded
        // corners of the overlay.
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final option = items[index];
              final isHighlighted = index == highlighted;
              return Builder(
                builder: (context) {
                  if (isHighlighted) {
                    // Keep the keyboard-driven selection on screen. Scheduled
                    // post-frame because the row is being laid out right now.
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        Scrollable.ensureVisible(context, alignment: 0.5);
                      }
                    });
                  }
                  return ListTile(
                    dense: dense,
                    selected: isHighlighted,
                    selectedTileColor: theme.focusColor,
                    leading: leadingFor?.call(context, option),
                    title: Text(labelFor(option)),
                    onTap: () => onSelected(option),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
