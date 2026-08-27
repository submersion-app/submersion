import 'package:flutter/material.dart';
import 'package:submersion/core/text/fuzzy_match.dart';

/// A text field with an autocomplete dropdown backed by a fixed [suggestions]
/// list. Wraps [RawAutocomplete] so an external [controller] (and the form
/// validation/decoration around it) is preserved.
///
/// When [enableFuzzy] is true the dropdown also surfaces fuzzy near-matches
/// (ranked by Dice score) below the plain substring matches; otherwise it
/// shows substring matches only. An empty query shows nothing (avoids dumping
/// a long list on focus).
class SuggestionField extends StatefulWidget {
  const SuggestionField({
    super.key,
    required this.suggestions,
    required this.decoration,
    this.controller,
    this.validator,
    this.enableFuzzy = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final List<String> suggestions;
  final InputDecoration decoration;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool enableFuzzy;
  final TextCapitalization textCapitalization;

  @override
  State<SuggestionField> createState() => _SuggestionFieldState();
}

class _SuggestionFieldState extends State<SuggestionField> {
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    // RawAutocomplete requires controller and focusNode to be both null or
    // both non-null. When the caller supplies a controller we own a focus node
    // to pair with it (we must NOT dispose the external controller).
    if (widget.controller != null) {
      _focusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _focusNode?.dispose();
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
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => _optionsFor(value.text),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: widget.decoration,
          validator: widget.validator,
          textCapitalization: widget.textCapitalization,
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
    );
  }
}
