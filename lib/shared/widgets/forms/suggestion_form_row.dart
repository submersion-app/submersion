import 'package:flutter/material.dart';

import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/shared/widgets/forms/autocomplete_options_list.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

/// Row-styled autocomplete text field: label left, always-mounted bare
/// field right (safe for validators inside always-open sections), with a
/// dropdown that offers substring matches first, then fuzzy near-matches
/// when [enableFuzzy].
///
/// [caption] renders muted under the row (merge source label);
/// [trailing] docks a widget after the field (merge cycle button).
/// With an empty [suggestions] list this is simply a merge-capable text
/// row — the overlay never appears.
class SuggestionFormRow extends StatefulWidget {
  const SuggestionFormRow({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    this.validator,
    this.enableFuzzy = false,
    this.textCapitalization = TextCapitalization.none,
    this.placeholder,
    this.maxLines = 1,
    this.caption,
    this.trailing,
    this.markdown = false,
  }) : assert(
         !markdown || suggestions.length == 0,
         'A Markdown notes row offers no suggestions',
       );

  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final String? Function(String?)? validator;
  final bool enableFuzzy;
  final TextCapitalization textCapitalization;
  final String? placeholder;
  final int maxLines;
  final String? caption;
  final Widget? trailing;

  /// A Markdown notes row (#3683): the label and [trailing] sit above the
  /// notes editor with its formatting bar, in place of the autocomplete
  /// field.
  final bool markdown;

  @override
  State<SuggestionFormRow> createState() => _SuggestionFormRowState();
}

class _SuggestionFormRowState extends State<SuggestionFormRow> {
  // RawAutocomplete requires controller and focusNode together; we own the
  // node and must never dispose the external controller.
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _optionsFor(String text) {
    final query = text.trim();
    if (query.isEmpty) return const Iterable<String>.empty();
    final lower = query.toLowerCase();

    final substring = widget.suggestions
        .where((s) => s.toLowerCase().contains(lower))
        .toList();
    if (!widget.enableFuzzy) return substring;

    final substringSet = substring.map((s) => s.toLowerCase()).toSet();
    final fuzzy =
        widget.suggestions
            .where((s) => !substringSet.contains(s.toLowerCase()))
            .map((s) => (s, diceCoefficient(query, s)))
            .where((pair) => pair.$2 >= 0.7)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    return [...substring, ...fuzzy.map((pair) => pair.$1)];
  }

  /// The row's label, kept out of the semantics tree because the field
  /// carries the same words as its name.
  Widget _visibleLabel(ThemeData theme) => ExcludeSemantics(
    child: Text(widget.label, style: theme.textTheme.bodyMedium),
  );

  /// Names the field after its row, so a screen reader announces the label
  /// with the text rather than an unnamed text box (issue #4166).
  Widget _namedField(Widget field) =>
      Semantics(container: true, label: widget.label, child: field);

  Widget _caption(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      widget.caption!,
      style: theme.textTheme.bodySmall!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _markdownRow(ThemeData theme) {
    return Padding(
      padding: FormStyle.rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _visibleLabel(theme)),
              ?widget.trailing,
            ],
          ),
          const SizedBox(height: 4),
          MarkdownNotesField(
            controller: widget.controller,
            focusNode: _focusNode,
            semanticsLabel: widget.label,
            validator: widget.validator,
            maxLines: widget.maxLines,
            textCapitalization: widget.textCapitalization,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: widget.placeholder,
            ),
          ),
          if (widget.caption != null) _caption(theme),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.markdown) return _markdownRow(theme);
    return Padding(
      padding: FormStyle.rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              _visibleLabel(theme),
              const SizedBox(width: 12),
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: widget.controller,
                  focusNode: _focusNode,
                  optionsBuilder: (value) => _optionsFor(value.text),
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return _namedField(
                          TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            validator: widget.validator,
                            textCapitalization: widget.textCapitalization,
                            maxLines: widget.maxLines,
                            textAlign: widget.maxLines > 1
                                ? TextAlign.start
                                : TextAlign.end,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: widget.placeholder,
                            ),
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                          ),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) =>
                      AutocompleteOptionsList<String>(
                        options: options,
                        onSelected: onSelected,
                        labelFor: (option) => option,
                      ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
          if (widget.caption != null) _caption(theme),
        ],
      ),
    );
  }
}
