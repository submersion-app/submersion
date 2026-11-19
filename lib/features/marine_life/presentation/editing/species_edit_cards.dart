import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_edit_fields.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_header_card_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The species page's cards that can be edited in place (issue #4527,
/// phase 3), by card id. The Photos card joins in a later task.
final Map<SpeciesCardId, EditCard<Species>> speciesEditCards = {
  SpeciesCardId.header: EditCard<Species>(
    id: SpeciesCardId.header.name,
    title: (context) => SpeciesCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    // The common name is required, as the form's validator has it.
    isValid: (session) =>
        session.valueOf(speciesCommonNameField).trim().isNotEmpty,
    editorBuilder: (context, session) =>
        SpeciesHeaderCardEditor(session: session),
  ),
  SpeciesCardId.description: EditCard<Species>(
    id: SpeciesCardId.description.name,
    title: (context) =>
        SpeciesCardId.description.localizedDisplayName(context.l10n),
    isEmpty: (s) => (s.description ?? '').trim().isEmpty,
    editorBuilder: (context, session) =>
        SpeciesDescriptionCardEditor(session: session),
  ),
};

/// The Description card's editor: the description as Markdown, written
/// through to the sitting as the diver types.
class SpeciesDescriptionCardEditor extends StatefulWidget {
  const SpeciesDescriptionCardEditor({super.key, required this.session});

  final EditSession<Species> session;

  @override
  State<SpeciesDescriptionCardEditor> createState() =>
      _SpeciesDescriptionCardEditorState();
}

class _SpeciesDescriptionCardEditorState
    extends State<SpeciesDescriptionCardEditor> {
  late final _binding = FieldTextBinding<Species, String?>(
    session: widget.session,
    field: speciesDescriptionField,
    format: (value) => value ?? '',
    // Any text is a value: blank is no description.
    parse: FieldValue<String?>.new,
  );

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MarkdownNotesField(
    controller: _binding.controller,
    autofocus: true,
    decoration: InputDecoration(
      hintText: context.l10n.marineLife_speciesEdit_descriptionLabel,
    ),
  );
}
