import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/widgets/document_form_fields.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_field.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_picker_sheet.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/scoped_tags_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

const String _tagObjectsKey = 'document.tags.objects';

/// Holds [tags] as the document's tags in [session]: the ids for the save,
/// the tags themselves for the page to show while the sitting is open. Back
/// to the stored set holds nothing, so the page follows the stored tags
/// again.
void holdDocumentTags(EditSession<DocumentRecord> session, List<Tag> tags) {
  final ids = [for (final t in tags) t.id];
  final unchanged = DocumentRecord.sameTags(ids, session.stored.tagIds);
  session
    ..remember(_tagObjectsKey, unchanged ? null : tags)
    ..set(documentTagsField, ids);
}

/// The tags [session] holds for the document, or null when the diver has
/// not changed them in the sitting.
List<Tag>? heldDocumentTags(EditSession<DocumentRecord> session) =>
    session.isDisposed ? null : session.recall<List<Tag>>(_tagObjectsKey);

/// The document's Details card editor (issue #4527, phase 3): the form's
/// fields, bound to the sitting, with the form's rules: a certification
/// card keeps its owner and type and has no title, expiry or reminder; only
/// insurance keeps its phones and primary; the default reminder is stored
/// as none; tags read only when they could not be read.
class DocumentDetailsCardEditor extends ConsumerStatefulWidget {
  const DocumentDetailsCardEditor({super.key, required this.session});

  final EditSession<DocumentRecord> session;

  @override
  ConsumerState<DocumentDetailsCardEditor> createState() =>
      _DocumentDetailsCardEditorState();
}

class _DocumentDetailsCardEditorState
    extends ConsumerState<DocumentDetailsCardEditor> {
  EditSession<DocumentRecord> get _session => widget.session;

  late final _bindings = <FieldTextBinding<DocumentRecord, Object?>>[];

  FieldTextBinding<DocumentRecord, V> _bind<V>(
    EditField<DocumentRecord, V> field,
    String Function(V value) format,
  ) {
    final binding = FieldTextBinding<DocumentRecord, V>.plain(
      session: _session,
      field: field,
      format: format,
    );
    _bindings.add(binding as FieldTextBinding<DocumentRecord, Object?>);
    return binding;
  }

  late final _controllers = DocumentFormControllers(
    title: _bind<String>(documentTitleField, (v) => v).controller,
    issuer: _bind<String?>(documentIssuerField, (v) => v ?? '').controller,
    number: _bind<String?>(
      documentReferenceNumberField,
      (v) => v ?? '',
    ).controller,
    emergencyPhone: _bind<String?>(
      documentEmergencyPhoneField,
      (v) => v ?? '',
    ).controller,
    phone: _bind<String?>(documentPhoneField, (v) => v ?? '').controller,
    notes: _bind<String>(documentNotesField, (v) => v).controller,
  );

  @override
  void dispose() {
    for (final binding in _bindings) {
      binding.dispose();
    }
    super.dispose();
  }

  Future<void> _pickOwner(DocumentOwner current) async {
    final picked = await showDocumentOwnerPicker(context, current: current);
    if (picked != null) _session.set(documentOwnerField, picked);
  }

  Future<void> _pickDate(EditField<DocumentRecord, DateTime?> field) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _session.valueOf(field) ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) _session.set(field, picked);
  }

  /// The tags shown: those the diver chose in this sitting, else [stored].
  List<Tag> _tags(List<Tag> stored) => heldDocumentTags(_session) ?? stored;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    // Watched here, in the editor's own build, not in the builder below.
    final storedTags =
        ref
            .watch(
              tagsForItemProvider((
                scope: TagScope.documents,
                itemId: _session.stored.id,
              )),
            )
            .value ??
        const <Tag>[];
    // Touch the controllers so every binding exists before the first frame.
    final controllers = _controllers;
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final working = _session.working;
        final doc = working.document;
        final tagsReadable = working.tagIds != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Not offered for a document another record's open Documents
            // card is creating: that record holds the link itself.
            if (!documentOwnerFixed(_session)) ...[
              DocumentOwnerField(
                owner: doc.owner,
                locked: documentOwnerLocked(doc),
                onTap: () => _pickOwner(doc.owner),
              ),
              const SizedBox(height: 12),
            ],
            DocumentFormFields(
              type: doc.type,
              typeChoices: documentTypeChoices(doc),
              controllers: controllers,
              issueDate: doc.issueDate,
              expiryDate: documentHasTitleExpiryAndReminder(doc)
                  ? doc.expiryDate
                  : null,
              reminderLeadDays: doc.effectiveReminderLeadDays,
              isPrimary: doc.isPrimary,
              formatDate: units.formatDate,
              onTypeChanged: (type) => setDocumentType(_session, type),
              onPickIssueDate: () => _pickDate(documentIssueDateField),
              onPickExpiryDate: () => _pickDate(documentExpiryDateField),
              onClearIssueDate: () =>
                  _session.set(documentIssueDateField, null),
              onClearExpiryDate: () =>
                  _session.set(documentExpiryDateField, null),
              onLeadChanged: (days) => _session.set(
                documentReminderLeadField,
                storedReminderLead(days),
              ),
              onPrimaryChanged: (value) =>
                  _session.set(documentPrimaryField, value),
            ),
            const SizedBox(height: 12),
            MarkdownNotesField(
              controller: controllers.notes,
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            ScopedTagsField(
              scope: TagScope.documents,
              label: l10n.documents_field_tags,
              browseKey: const ValueKey('document_details_tags_browse'),
              selectedTags: _tags(storedTags),
              enabled: tagsReadable,
              onTagsChanged: (tags) => holdDocumentTags(_session, tags),
            ),
          ],
        );
      },
    );
  }
}
