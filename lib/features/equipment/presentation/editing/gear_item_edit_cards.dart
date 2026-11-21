import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_findings_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/observations_card.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_photos_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_documents_section.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_clocks_editor.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_details_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_cards.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The gear item page's cards that can be edited in place (issue #4527,
/// phase 3, plan 6), by card id, in page order.
final Map<GearItemCardId, EditCard<EquipmentItem>> gearItemEditCards = {
  GearItemCardId.header: EditCard<EquipmentItem>(
    id: GearItemCardId.header.name,
    title: (context) =>
        GearItemCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    // A name, as the form's validator had it.
    isValid: (session) => gearNameValid(session.working.name),
    editorBuilder: (context, session) => GearItemHeaderEditor(session: session),
  ),
  GearItemCardId.diveComputer: EditCard<EquipmentItem>(
    id: GearItemCardId.diveComputer.name,
    title: (context) =>
        GearItemCardId.diveComputer.localizedDisplayName(context.l10n),
    // Shown for a computer item only, as the page always has.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        DiveComputerSection(equipmentId: session.stored.id, editing: session),
  ),
  GearItemCardId.details: EditCard<EquipmentItem>(
    id: GearItemCardId.details.name,
    title: (context) =>
        GearItemCardId.details.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    // A readable price, as the form's validator had it.
    isValid: gearDetailsValid,
    editorBuilder: (context, session) =>
        GearItemDetailsEditor(session: session),
  ),
  GearItemCardId.location: EditCard<EquipmentItem>(
    id: GearItemCardId.location.name,
    title: (context) =>
        GearItemCardId.location.localizedDisplayName(context.l10n),
    // Always on the page: with no place, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        EquipmentLocationCard(equipment: session.working, editing: session),
  ),
  GearItemCardId.twinSet: EditCard<EquipmentItem>(
    id: GearItemCardId.twinSet.name,
    title: (context) =>
        GearItemCardId.twinSet.localizedDisplayName(context.l10n),
    // A tank's, with none it says so; it hides itself for doubles kept as
    // one item.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => TwinSetCard(
      equipmentId: session.stored.id,
      working: session.working,
      editing: session,
    ),
  ),
  GearItemCardId.serviceClocks: EditCard<EquipmentItem>(
    id: GearItemCardId.serviceClocks.name,
    title: (context) =>
        GearItemCardId.serviceClocks.localizedDisplayName(context.l10n),
    // On the page for owned gear, with none it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => GearItemClocksEditor(session: session),
  ),
  GearItemCardId.serviceHistory: EditCard<EquipmentItem>(
    id: GearItemCardId.serviceHistory.name,
    title: (context) =>
        GearItemCardId.serviceHistory.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        ServiceHistorySection(equipmentId: session.stored.id, editing: session),
  ),
  GearItemCardId.conditionFindings: EditCard<EquipmentItem>(
    id: GearItemCardId.conditionFindings.name,
    title: (context) =>
        GearItemCardId.conditionFindings.localizedDisplayName(context.l10n),
    // Calculated rows the diver can dismiss; it hides itself when it has
    // nothing to show.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        ConditionFindingsCard(equipment: session.working, editing: session),
  ),
  GearItemCardId.photos: EditCard<EquipmentItem>(
    id: GearItemCardId.photos.name,
    title: (context) =>
        GearItemCardId.photos.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        EquipmentPhotosSection(equipment: session.working, editing: session),
  ),
  GearItemCardId.observations: EditCard<EquipmentItem>(
    id: GearItemCardId.observations.name,
    title: (context) =>
        GearItemCardId.observations.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        ObservationsCard(equipment: session.working, editing: session),
  ),
  GearItemCardId.components: EditCard<EquipmentItem>(
    id: GearItemCardId.components.name,
    title: (context) =>
        GearItemCardId.components.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        ComponentsCard(equipmentId: session.stored.id, editing: session),
  ),
  GearItemCardId.legacyFiles: EditCard<EquipmentItem>(
    id: GearItemCardId.legacyFiles.name,
    title: (context) =>
        GearItemCardId.legacyFiles.localizedDisplayName(context.l10n),
    // On the page only while files are left; nothing can be added to it.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => Consumer(
      builder: (context, ref, _) => EquipmentDocumentsSection(
        equipmentId: session.stored.id,
        editing: session,
        onOpenDocument: (item) => DocumentOpenHelper.open(context, ref, item),
      ),
    ),
  ),
  GearItemCardId.notes: EditCard<EquipmentItem>(
    id: GearItemCardId.notes.name,
    title: (context) => GearItemCardId.notes.localizedDisplayName(context.l10n),
    isEmpty: (e) => e.notes.trim().isEmpty,
    editorBuilder: (context, session) => GearItemNotesEditor(session: session),
  ),
  GearItemCardId.documents: EditCard<EquipmentItem>(
    id: GearItemCardId.documents.name,
    title: (context) =>
        GearItemCardId.documents.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DocumentsSection<EquipmentItem>(
      owner: DocumentOwner(DocumentOwnerKind.equipment, session.stored.id),
      editing: session,
    ),
  ),
  // The passports' cards (plan 7): the item page shows none of them, but a
  // passport joins its sitting, so its Save checks them too.
  GearItemCardId.passportFills: passportFillsCard,
  GearItemCardId.passportTag: passportTagCard(),
  GearItemCardId.passportTrip: passportTripCard,
};

/// The cards the page leaves out while they are empty, offered in the
/// strip, in page order.
const List<GearItemCardId> gearItemOptionalCards = [GearItemCardId.notes];

/// The Notes card's editor: the item's notes, in Markdown.
class GearItemNotesEditor extends StatefulWidget {
  const GearItemNotesEditor({super.key, required this.session});

  final EditSession<EquipmentItem> session;

  @override
  State<GearItemNotesEditor> createState() => _GearItemNotesEditorState();
}

class _GearItemNotesEditorState extends State<GearItemNotesEditor> {
  late final _binding = FieldTextBinding<EquipmentItem, String>.plain(
    session: widget.session,
    field: gearNotesField,
    format: (v) => v,
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
      labelText: context.l10n.equipment_edit_notesLabel,
      prefixIcon: const Icon(Icons.notes),
      hintText: context.l10n.equipment_edit_notesHint,
      alignLabelWithHint: true,
    ),
    maxLines: 4,
    textCapitalization: TextCapitalization.sentences,
  );
}
