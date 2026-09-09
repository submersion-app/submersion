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
class AutocompleteOptionsList<T extends Object> extends StatefulWidget {
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
  State<AutocompleteOptionsList<T>> createState() =>
      _AutocompleteOptionsListState<T>();
}

class _AutocompleteOptionsListState<T extends Object>
    extends State<AutocompleteOptionsList<T>> {
  final _scrollController = ScrollController();

  // Keyed by position rather than by option value: two suggestions can be
  // equal strings, and duplicate global keys would break the tree.
  final _rowKeys = <int, GlobalKey>{};

  int? _highlighted;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _rowKey(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  /// Brings the row at [index] on screen after the frame that highlighted it.
  ///
  /// The jump-to-first and jump-to-last intents can land outside the rows the
  /// [ListView] has built, and [Scrollable.ensureVisible] needs a live
  /// context, so those fall back to scrolling to that end of the list. The
  /// stepping intents (arrow keys, PageUp/PageDown) move only a few rows at a
  /// time, so their target is already built and takes the exact path.
  void _scrollHighlightIntoView(int index) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // A newer highlight has superseded this one, e.g. while an arrow key
      // is held down; that scroll is already scheduled.
      if (!mounted || index != _highlighted) return;
      if (!_scrollController.hasClients) return;

      final rowContext = _rowKeys[index]?.currentContext;
      if (rowContext == null) {
        // Only a jump to one end of the list can outrun the built rows.
        _scrollController.jumpTo(
          index == 0 ? 0 : _scrollController.position.maxScrollExtent,
        );
        return;
      }
      Scrollable.ensureVisible(rowContext, alignment: 0.5);
    }, debugLabel: 'AutocompleteOptionsList.ensureVisible');
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    final theme = Theme.of(context);
    // optionsBuilder commonly returns a lazy Iterable; materialise it once so
    // indexing rows is not quadratic in the number of matches.
    final items = widget.options.toList(growable: false);

    if (highlighted != _highlighted) {
      _highlighted = highlighted;
      if (highlighted < items.length) _scrollHighlightIntoView(highlighted);
    }

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        // Without a clip the rows' ink splashes paint past the rounded
        // corners of the overlay.
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final option = items[index];
              return ListTile(
                key: _rowKey(index),
                dense: widget.dense,
                selected: index == highlighted,
                selectedTileColor: theme.focusColor,
                leading: widget.leadingFor?.call(context, option),
                title: Text(widget.labelFor(option)),
                onTap: () => widget.onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }
}
