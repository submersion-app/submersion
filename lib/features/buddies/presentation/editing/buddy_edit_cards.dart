import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certifications_sitting.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_contact_card_editor.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_header_card_editor.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_gear_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The buddy page's cards that can be edited in place (issue #4527, phase
/// 3), by card id, in page order.
final Map<BuddyCardId, EditCard<Buddy>> buddyEditCards = {
  BuddyCardId.header: EditCard<Buddy>(
    id: BuddyCardId.header.name,
    title: (context) => BuddyCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    isValid: (session) => buddyNameValid(session.valueOf(buddyNameField)),
    editorBuilder: (context, session) =>
        BuddyHeaderCardEditor(session: session),
  ),
  BuddyCardId.contact: EditCard<Buddy>(
    id: BuddyCardId.contact.name,
    title: (context) => BuddyCardId.contact.localizedDisplayName(context.l10n),
    isEmpty: (b) =>
        !b.hasContactInfo &&
        b.socialHandle == null &&
        b.country == null &&
        b.linkedDiverId == null,
    isValid: (session) => buddyEmailValid(session.valueOf(buddyEmailField)),
    editorBuilder: (context, session) =>
        BuddyContactCardEditor(session: session),
  ),
  BuddyCardId.certifications: EditCard<Buddy>(
    id: BuddyCardId.certifications.name,
    title: (context) =>
        BuddyCardId.certifications.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        BuddyCertificationsCardEditor(session: session),
  ),
  BuddyCardId.statistics: EditCard<Buddy>(
    id: BuddyCardId.statistics.name,
    title: (context) =>
        BuddyCardId.statistics.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        BuddyStatisticsCardEditor(session: session),
  ),
  BuddyCardId.gear: EditCard<Buddy>(
    id: BuddyCardId.gear.name,
    title: (context) => BuddyCardId.gear.localizedDisplayName(context.l10n),
    // The page offers it in the strip while the buddy has none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        BuddyGearSection(buddy: session.working, editing: session),
  ),
  BuddyCardId.notes: EditCard<Buddy>(
    id: BuddyCardId.notes.name,
    title: (context) => BuddyCardId.notes.localizedDisplayName(context.l10n),
    isEmpty: (b) => b.notes.trim().isEmpty,
    editorBuilder: (context, session) => BuddyNotesCardEditor(session: session),
  ),
  BuddyCardId.documents: EditCard<Buddy>(
    id: BuddyCardId.documents.name,
    title: (context) =>
        BuddyCardId.documents.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DocumentsSection<Buddy>(
      owner: DocumentOwner(DocumentOwnerKind.buddy, session.stored.id),
      editing: session,
    ),
  ),
};

/// The cards the page leaves out while they are empty, offered in the
/// strip, in page order.
const List<BuddyCardId> buddyOptionalCards = [
  BuddyCardId.contact,
  BuddyCardId.notes,
];

/// The Statistics card's editor: whether the buddy is left out of the
/// rankings (issue #3624). The figures themselves are calculated.
class BuddyStatisticsCardEditor extends StatelessWidget {
  const BuddyStatisticsCardEditor({super.key, required this.session});

  final EditSession<Buddy> session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => SwitchListTile(
        key: const ValueKey('buddy-edit-rankings'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.buddies_field_excludedFromRankings),
        subtitle: Text(l10n.buddies_field_excludedFromRankingsHint),
        value: session.valueOf(buddyExcludedFromRankingsField),
        onChanged: (value) =>
            session.set(buddyExcludedFromRankingsField, value),
      ),
    );
  }
}

/// The Notes card's editor, as Markdown.
class BuddyNotesCardEditor extends StatefulWidget {
  const BuddyNotesCardEditor({super.key, required this.session});

  final EditSession<Buddy> session;

  @override
  State<BuddyNotesCardEditor> createState() => _BuddyNotesCardEditorState();
}

class _BuddyNotesCardEditorState extends State<BuddyNotesCardEditor> {
  late final _binding = FieldTextBinding<Buddy, String>(
    session: widget.session,
    field: buddyNotesField,
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
      labelText: context.l10n.buddies_field_notes,
      hintText: context.l10n.buddies_field_notesHint,
      alignLabelWithHint: true,
    ),
    maxLines: 4,
  );
}
