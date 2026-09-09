import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/text/fuzzy_match.dart';

import 'package:submersion/features/dive_log/presentation/utils/filter_option_search.dart';
import 'package:submersion/shared/widgets/forms/autocomplete_options_list.dart';

/// Identifies this field's floating suggestion list.
///
/// Tests scope their finders to this rather than to every tappable row on the
/// surface under it, which would otherwise match unrelated buttons and could
/// mask a failure once a page grows a control sharing an option's label.
const searchableFilterOptionsKey = Key('searchable-filter-options');

/// One selectable entry in a [SearchableFilterDropdown].
///
/// [label] is what the diver sees; [searchText] is what typing matches
/// against, which lets an option be found by text that is not on its label
/// (a dive site by its country, for example). Build [searchText] with
/// [buildFilterSearchText].
@immutable
class FilterDropdownOption<T> {
  FilterDropdownOption({
    required this.value,
    required this.label,
    String? searchText,
  }) : _searchText = searchText;

  final T value;
  final String label;
  final String? _searchText;

  /// The haystack typing is matched against, defaulting to the label.
  String get searchText => _searchText ?? label;

  /// [searchText] normalized, computed once per option and reused for every
  /// keystroke. Normalizing per keystroke instead costs about 5.8ms per
  /// keystroke over 2000 options, most of a frame; this brings it to 0.1ms.
  late final String normalizedSearchText = normalize(searchText);

  // Value equality so the field can tell a host rebuild that changed nothing
  // (these are built fresh on every parent build) from one that actually
  // changed the options, and keep its prepared rows in the first case.
  @override
  bool operator ==(Object other) =>
      other is FilterDropdownOption<T> &&
      other.value == value &&
      other.label == label &&
      other._searchText == _searchText;

  @override
  int get hashCode => Object.hash(value, label, _searchText);
}

/// One row offered by the field, including the leading "all options" row that
/// clears the filter and so carries a null value.
@immutable
class _FilterEntry<T> {
  const _FilterEntry({
    required this.value,
    required this.label,
    required this.normalizedSearchText,
  });

  final T? value;
  final String label;

  /// Already normalized, so matching a keystroke costs a substring test.
  final String normalizedSearchText;
}

/// A filter field that narrows its options as the diver types.
///
/// Built on [RawAutocomplete] rather than [DropdownMenu] deliberately.
/// DropdownMenu's menu is a [RawMenuAnchor], which listens to the nearest
/// ancestor scrollable and closes on any scroll; focusing its text field makes
/// the caret animate into view, which scrolls the filter sheet's list, so the
/// menu closed the frame after it opened. RawAutocomplete's overlay has no
/// such listener, and it is already the pattern the buddy field in this same
/// sheet uses.
///
/// The selection is always one of [options] or null. Typed text is only ever a
/// query, never a value: text that matches nothing is discarded when the field
/// loses focus, so the field never shows something that is not the filter
/// actually in force.
class SearchableFilterDropdown<T> extends StatefulWidget {
  const SearchableFilterDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.allOptionLabel,
    required this.searchHintText,
    required this.onChanged,
    this.labelText,
    this.icon,
  });

  /// The currently selected option value, or null for "no filter".
  final T? value;

  final List<FilterDropdownOption<T>> options;

  /// Label of the leading entry that clears the filter.
  final String allOptionLabel;

  /// Shown under the field, as the standing cue that it can be typed into.
  ///
  /// Not a [InputDecoration.hintText]: the field always carries the label of
  /// the current selection, so a hint would only ever surface if the diver
  /// deleted that text, which is exactly when they no longer need telling.
  final String searchHintText;

  /// Optional floating label, for forms that name their fields rather than
  /// relying on a section heading above them.
  final String? labelText;

  final IconData? icon;

  final ValueChanged<T?> onChanged;

  @override
  State<SearchableFilterDropdown<T>> createState() =>
      _SearchableFilterDropdownState<T>();
}

class _SearchableFilterDropdownState<T>
    extends State<SearchableFilterDropdown<T>> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// The selection the field is showing. Follows
  /// [SearchableFilterDropdown.value], but is set the moment the diver picks a
  /// row rather than waiting for the host to rebuild the field with the new
  /// value. Without it, dropping focus on the way out of a pick restored the
  /// label of the selection being replaced.
  late T? _selectedValue;

  /// The rows offered to the diver, prepared once per option list rather than
  /// on every keystroke: [_optionsFor] runs per keystroke, and rebuilding this
  /// there allocated a row per option each time.
  late List<_FilterEntry<T>> _entries;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
    _controller.text = _selectedLabel;
    _entries = _buildEntries();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchableFilterDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.options, widget.options) ||
        oldWidget.allOptionLabel != widget.allOptionLabel) {
      _entries = _buildEntries();
    }
    if (widget.value != oldWidget.value) {
      _selectedValue = widget.value;
    }
    // While the field is not being edited its text IS the selection's label,
    // so anything that moves that label has to reach it: a selection made
    // elsewhere (Clear All, a preset), an option renamed under the same id, an
    // option list that resolved after the first build, a locale switch.
    if (!_focusNode.hasFocus && _controller.text != _selectedLabel) {
      _controller.text = _selectedLabel;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final label = _selectedLabel;
    if (_focusNode.hasFocus) {
      // Select the whole label so the first keystroke starts a fresh query
      // instead of appending to the name of the current selection.
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      return;
    }
    // Discard a query the diver typed but never committed, so the field falls
    // back to showing the filter that is actually in force.
    if (_controller.text != label) {
      _controller.text = label;
    }
  }

  /// The label of the current selection, or the "all options" label when the
  /// filter is off.
  String get _selectedLabel {
    final value = _selectedValue;
    if (value == null) return widget.allOptionLabel;
    for (final option in widget.options) {
      if (option.value == value) return option.label;
    }
    // The option went away (deleted since the filter was set); the caller
    // resets the id, so show the unfiltered label rather than a stale name.
    return widget.allOptionLabel;
  }

  List<_FilterEntry<T>> _buildEntries() => [
    _FilterEntry<T>(
      value: null,
      label: widget.allOptionLabel,
      normalizedSearchText: normalize(widget.allOptionLabel),
    ),
    ...widget.options.map(
      (option) => _FilterEntry<T>(
        value: option.value,
        label: option.label,
        normalizedSearchText: option.normalizedSearchText,
      ),
    ),
  ];

  Iterable<_FilterEntry<T>> _optionsFor(TextEditingValue textEditingValue) {
    final query = textEditingValue.text;
    // The field carries the current selection's label when it is not being
    // edited. Treating that as a query would offer only the row already
    // chosen, so opening the field always offers everything.
    if (query.trim().isEmpty || query == _selectedLabel) {
      return _entries;
    }
    final filterQuery = FilterOptionQuery(query);
    return _entries.where(
      (entry) => filterQuery.matches(entry.normalizedSearchText),
    );
  }

  void _onSelected(_FilterEntry<T> entry) {
    _selectedValue = entry.value;
    _controller.text = entry.label;
    _controller.selection = TextSelection.collapsed(offset: entry.label.length);
    widget.onChanged(entry.value);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<_FilterEntry<T>>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: _optionsFor,
      displayStringForOption: (entry) => entry.label,
      onSelected: _onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText,
              helperText: widget.searchHintText,
              prefixIcon: widget.icon == null ? null : Icon(widget.icon),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            // Commits the highlighted suggestion; a no-op when the option list
            // is closed, so a stray submit cannot change the filter.
            onSubmitted: (_) => onFieldSubmitted(),
          ),
      optionsViewBuilder: (context, onSelected, options) =>
          AutocompleteOptionsList<_FilterEntry<T>>(
            key: searchableFilterOptionsKey,
            options: options,
            onSelected: onSelected,
            labelFor: (entry) => entry.label,
            maxHeight: 240,
          ),
    );
  }
}
