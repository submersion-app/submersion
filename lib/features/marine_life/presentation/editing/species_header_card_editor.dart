import 'package:flutter/material.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_edit_fields.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// Opens the online species lookup with [query] typed in, as the old edit
/// form did; a seam, so a page test can answer for it.
typedef SpeciesLookupLauncher =
    Future<SpeciesLookupOutcome?> Function(BuildContext context, String query);

final speciesLookupLauncherProvider = Provider<SpeciesLookupLauncher>(
  (ref) =>
      (context, query) => showSpeciesLookupSheet(context, initialQuery: query),
);

/// The species header block's editor (issue #4527, phase 3): the common
/// name, which is required, the online lookup, the scientific name, the
/// category and the taxonomy class. It edits the stored text, not the
/// translation a built-in species shows.
class SpeciesHeaderCardEditor extends ConsumerStatefulWidget {
  const SpeciesHeaderCardEditor({super.key, required this.session});

  final EditSession<Species> session;

  @override
  ConsumerState<SpeciesHeaderCardEditor> createState() =>
      _SpeciesHeaderCardEditorState();
}

class _SpeciesHeaderCardEditorState
    extends ConsumerState<SpeciesHeaderCardEditor> {
  late final _common = _bind<String>(speciesCommonNameField, (v) => v);
  late final _scientific = _bind<String?>(
    speciesScientificNameField,
    (v) => v ?? '',
  );
  late final _taxonomy = _bind<String?>(
    speciesTaxonomyClassField,
    (v) => v ?? '',
  );

  FieldTextBinding<Species, V> _bind<V>(
    EditField<Species, V> field,
    String Function(V value) format,
  ) => FieldTextBinding.plain(
    session: widget.session,
    field: field,
    format: format,
  );

  @override
  void dispose() {
    _common.dispose();
    _scientific.dispose();
    _taxonomy.dispose();
    super.dispose();
  }

  /// Fills the names, taxonomy and category from the lookup's choice, each
  /// a change of the header, as the form's lookup fills its fields.
  Future<void> _lookUp() async {
    final launch = ref.read(speciesLookupLauncherProvider);
    final outcome = await launch(
      context,
      widget.session.valueOf(speciesCommonNameField).trim(),
    );
    if (outcome is! SpeciesLookupChosen || widget.session.isDisposed) return;
    final result = outcome.result;
    widget.session
      ..set(speciesCommonNameField, result.commonName)
      ..set(speciesScientificNameField, result.scientificName)
      ..set(speciesTaxonomyClassField, result.taxonomyClass ?? '')
      ..set(speciesCategoryField, result.category);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final blank = widget.session
            .valueOf(speciesCommonNameField)
            .trim()
            .isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('species_header_common_name'),
              controller: _common.controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.marineLife_speciesEdit_commonNameLabel,
                errorText: blank
                    ? l10n.marineLife_speciesEdit_commonNameError
                    : null,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('species_lookup_online'),
                icon: const Icon(Icons.travel_explore),
                label: Text(l10n.marineLife_lookup_button),
                onPressed: _lookUp,
              ),
            ),
            TextField(
              controller: _scientific.controller,
              decoration: InputDecoration(
                labelText: l10n.marineLife_speciesEdit_scientificNameLabel,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SpeciesCategory>(
              key: ValueKey(
                'species_header_category_'
                '${widget.session.valueOf(speciesCategoryField).name}',
              ),
              initialValue: widget.session.valueOf(speciesCategoryField),
              decoration: InputDecoration(
                labelText: l10n.marineLife_speciesEdit_categoryLabel,
              ),
              items: [
                for (final category in SpeciesCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.localizedName(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  widget.session.set(speciesCategoryField, value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taxonomy.controller,
              decoration: InputDecoration(
                labelText: l10n.marineLife_speciesEdit_taxonomyClassLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}
