import 'package:flutter/material.dart';

import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Row-styled autocomplete text field: label left, always-mounted bare
/// field right (safe for validators inside always-open sections), with the
/// SuggestionField dropdown behavior (substring matches, then fuzzy
/// near-matches when [enableFuzzy]).
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
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text(widget.label, style: theme.textTheme.bodyMedium),
              const SizedBox(width: 12),
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: widget.controller,
                  focusNode: _focusNode,
                  optionsBuilder: (value) => _optionsFor(value.text),
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
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
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
          if (widget.caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.caption!,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
