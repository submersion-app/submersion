import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/autocomplete_options_list.dart';
import 'package:submersion/shared/widgets/forms/suggestion_matching.dart';

/// The buddy edit page's Country field (issue #4457): free text, like a
/// site's country, offering [suggestions] that contain what was typed.
///
/// [decoration] is the field's full decoration, so the page can add its
/// merge-cycle helper and button as it does for the other contact fields.
class BuddyCountryField extends StatefulWidget {
  const BuddyCountryField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.decoration,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final InputDecoration decoration;

  @override
  State<BuddyCountryField> createState() => _BuddyCountryFieldState();
}

class _BuddyCountryFieldState extends State<BuddyCountryField> {
  // RawAutocomplete takes a controller and a focus node together; the page
  // owns the controller, so only the node is this widget's to dispose.
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) =>
          suggestionsContaining(widget.suggestions, value.text),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: widget.decoration,
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (_) => onFieldSubmitted(),
          ),
      optionsViewBuilder: (context, onSelected, options) =>
          AutocompleteOptionsList<String>(
            options: options,
            onSelected: onSelected,
            labelFor: (option) => option,
          ),
    );
  }
}
