import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/shared/widgets/forms/autocomplete_options_list.dart';

/// How many names the brand and model fields suggest at once.
const int kCatalogueSuggestionLimit = 8;

/// [names] that match [typed]: those starting with it first, then those
/// containing it, without case, spaces or punctuation, each name once and
/// none equal to what is typed. Nothing for a blank field.
List<String> _matching(Iterable<String> names, String typed) {
  final query = catalogueNameKey(typed);
  if (query.isEmpty) return const [];
  final seen = <String>{query};
  final starts = <String>[];
  final contains = <String>[];
  for (final name in names) {
    final key = catalogueNameKey(name);
    if (!key.contains(query) || !seen.add(key)) continue;
    (key.startsWith(query) ? starts : contains).add(name);
  }
  return [...starts, ...contains];
}

/// Brand names for the brand field of an item of [type]: the diver's own
/// brands ([diverBrands], their spelling) first, then the makers the
/// [catalogue] has a [type] record of, found by their own name or any other
/// name they go by and offered by their own spelling (issue #5118).
List<String> brandSuggestions(
  EquipmentCatalogue catalogue,
  EquipmentType type,
  Iterable<String> diverBrands,
  String typed,
) {
  final query = catalogueNameKey(typed);
  if (query.isEmpty) return const [];
  final mine = _matching(diverBrands, typed);
  final taken = {query, ...mine.map(catalogueNameKey)};
  final starts = <String>[];
  final contains = <String>[];
  final makers = catalogue.manufacturerKeys(type);
  for (final name in makers.keys.toList()..sort(compareTextForSort)) {
    final keys = makers[name]!;
    if (keys.any(taken.contains) || !keys.any((k) => k.contains(query))) {
      continue;
    }
    (keys.any((k) => k.startsWith(query)) ? starts : contains).add(name);
  }
  return [...mine, ...starts, ...contains];
}

/// Model names for the model field: the [catalogue]'s [type] models of the
/// maker in [brand]. Nothing until a brand is typed: model names alone are
/// too short to search usefully.
List<String> modelSuggestions(
  EquipmentCatalogue catalogue,
  EquipmentType type,
  String brand,
  String typed,
) => _matching(catalogue.models(type, brand).map((r) => r.model), typed);

/// A gear editor text field that suggests names as the diver types
/// (issue #5118). Picking one sets the field to that spelling and nothing
/// else; the field stays free text.
class CatalogueNameField extends StatefulWidget {
  const CatalogueNameField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.suggestionsFor,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  /// The names to offer for what is typed now.
  final List<String> Function(String typed) suggestionsFor;

  @override
  State<CatalogueNameField> createState() => _CatalogueNameFieldState();
}

class _CatalogueNameFieldState extends State<CatalogueNameField> {
  // RawAutocomplete takes a controller and a focus node together; this
  // field owns the node and never disposes the caller's controller.
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
          widget.suggestionsFor(value.text).take(kCatalogueSuggestionLimit),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(widget.icon),
            ),
            onSubmitted: (_) => onFieldSubmitted(),
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
