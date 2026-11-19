import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_contact_card_editor.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_header_card_editor.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_map_card_editor.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The dive centre page's cards that can be edited in place (issue #4527,
/// phase 3), by card id, in page order.
final Map<DiveCenterCardId, EditCard<DiveCenter>> diveCenterEditCards = {
  DiveCenterCardId.map: EditCard<DiveCenter>(
    id: DiveCenterCardId.map.name,
    title: (context) => DiveCenterCardId.map.localizedDisplayName(context.l10n),
    isEmpty: (c) => !c.hasCoordinates,
    isValid: (session) =>
        diveCenterCoordinatesValid(session.valueOf(diveCenterCoordinatesField)),
    editorBuilder: (context, session) =>
        DiveCenterMapCardEditor(session: session),
  ),
  DiveCenterCardId.header: EditCard<DiveCenter>(
    id: DiveCenterCardId.header.name,
    title: (context) =>
        DiveCenterCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    isValid: (session) =>
        session.valueOf(diveCenterNameField).trim().isNotEmpty,
    editorBuilder: (context, session) =>
        DiveCenterHeaderCardEditor(session: session),
  ),
  DiveCenterCardId.contact: EditCard<DiveCenter>(
    id: DiveCenterCardId.contact.name,
    title: (context) =>
        DiveCenterCardId.contact.localizedDisplayName(context.l10n),
    isEmpty: (c) =>
        c.phone == null &&
        c.email == null &&
        c.website == null &&
        c.fillOpensAt == null &&
        c.fillClosesAt == null,
    isValid: (session) {
      final hours = session.valueOf(diveCenterFillHoursField);
      return diveCenterEmailValid(session.valueOf(diveCenterEmailField)) &&
          fillHoursProblem(hours.opensAt, hours.closesAt) == null;
    },
    editorBuilder: (context, session) =>
        DiveCenterContactCardEditor(session: session),
  ),
  DiveCenterCardId.notes: EditCard<DiveCenter>(
    id: DiveCenterCardId.notes.name,
    title: (context) =>
        DiveCenterCardId.notes.localizedDisplayName(context.l10n),
    isEmpty: (c) => c.notes.trim().isEmpty,
    editorBuilder: (context, session) =>
        DiveCenterNotesCardEditor(session: session),
  ),
  DiveCenterCardId.rentalGear: EditCard<DiveCenter>(
    id: DiveCenterCardId.rentalGear.name,
    title: (context) =>
        DiveCenterCardId.rentalGear.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        RentalGearSection(centerId: session.stored.id, editing: session),
  ),
  DiveCenterCardId.documents: EditCard<DiveCenter>(
    id: DiveCenterCardId.documents.name,
    title: (context) =>
        DiveCenterCardId.documents.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DocumentsSection<DiveCenter>(
      owner: DocumentOwner(DocumentOwnerKind.diveCenter, session.stored.id),
      editing: session,
    ),
  ),
};

/// The cards the page leaves out while they are empty, offered in the
/// strip, in page order.
const List<DiveCenterCardId> diveCenterOptionalCards = [
  DiveCenterCardId.map,
  DiveCenterCardId.contact,
  DiveCenterCardId.notes,
];

/// The Notes card's editor, as Markdown.
class DiveCenterNotesCardEditor extends StatefulWidget {
  const DiveCenterNotesCardEditor({super.key, required this.session});

  final EditSession<DiveCenter> session;

  @override
  State<DiveCenterNotesCardEditor> createState() =>
      _DiveCenterNotesCardEditorState();
}

class _DiveCenterNotesCardEditorState extends State<DiveCenterNotesCardEditor> {
  late final _binding = FieldTextBinding<DiveCenter, String>(
    session: widget.session,
    field: diveCenterNotesField,
    format: (v) => v,
    parse: FieldValue<String>.new,
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
      labelText: context.l10n.diveCenters_section_notes,
      hintText: context.l10n.diveCenters_hint_notes,
      alignLabelWithHint: true,
    ),
    maxLines: 4,
  );
}
