import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/editing/instructor_card_editor.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_agency_dropdown.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_level_dialog.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_form_widgets.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The certification's card editors (issue #4527, phase 3), over any
/// sitting on a certification: the certification page's, and the dialog a
/// buddy's certification is edited in. Each sets only its own card's
/// values, with the old edit form's widgets and rules.

/// A text binding of [field], whose blank text is a value (none, for an
/// optional one).
FieldTextBinding<Certification, V> _bindText<V>(
  EditSession<Certification> session,
  EditField<Certification, V> field,
  String Function(V value) format,
) => FieldTextBinding.plain(session: session, field: field, format: format);

/// Details: the card's recognitions, its title and its number.
class CertificationDetailsCardEditor extends ConsumerStatefulWidget {
  const CertificationDetailsCardEditor({super.key, required this.session});

  final EditSession<Certification> session;

  @override
  ConsumerState<CertificationDetailsCardEditor> createState() =>
      _CertificationDetailsCardEditorState();
}

class _CertificationDetailsCardEditorState
    extends ConsumerState<CertificationDetailsCardEditor> {
  // A name that only repeats the agency and level (the old form filled it
  // in until 2026-08) shows blank, so the hint offers the derived title
  // instead of repeating it.
  late final _title = FieldTextBinding<Certification, String>(
    session: widget.session,
    field: certificationTitleField,
    format: (v) =>
        _repeatsCredentials(_session.working.copyWith(name: v)) ? '' : v,
    parse: FieldValue<String>.new,
    onEdited: () => _titleTyped = true,
  );

  /// Whether the diver has typed in the title in this sitting. Typing the
  /// stored text back is no change to the sitting, so the value alone
  /// cannot tell.
  bool _titleTyped = false;
  late final _cardNumber = _bindText<String?>(
    widget.session,
    certificationCardNumberField,
    (v) => v ?? '',
  );

  /// Bumped to remount a level field after the add action, so the action
  /// row is never left showing as the selection when the dialog is
  /// cancelled.
  int _levelRevision = 0;

  EditSession<Certification> get _session => widget.session;

  List<CertificationCredential> get _rows =>
      _session.valueOf(certificationCredentialsField);

  /// Whether [cert]'s name only repeats its agency and level.
  bool _repeatsCredentials(Certification cert) =>
      hasDerivedName(cert, catalog: context.certificationCatalog);

  /// Sets the recognitions. A stored name that only repeats the stored
  /// agency and level, which the field shows blank, follows them: cleared
  /// once they change, as the old form's blank field saved it (kept, it
  /// would read as a custom title on the new ones), and back when they
  /// return, so a change undone leaves nothing to save. A title the diver
  /// can see, stored or typed in this sitting, is theirs and stays.
  void _setRows(List<CertificationCredential> rows) {
    final stored = _session.stored;
    final title = _session.valueOf(certificationTitleField);
    final follows =
        !_titleTyped &&
        (title == stored.name || title.isEmpty) &&
        _repeatsCredentials(stored);
    _session.set(certificationCredentialsField, rows);
    if (!follows) return;
    final repeats = _repeatsCredentials(
      _session.working.copyWith(name: stored.name),
    );
    _session.set(certificationTitleField, repeats ? stored.name : '');
  }

  @override
  void dispose() {
    _title.dispose();
    _cardNumber.dispose();
    super.dispose();
  }

  /// The add action opens the certification dialog for [agency] and selects
  /// what it creates; any other option is an ordinary selection.
  Future<void> _onLevelChanged(
    int i,
    String agency,
    CertificationOption? option,
  ) async {
    if (option == null || !option.isAddCustom) {
      _setRows(setCredentialLevel(_rows, i, option?.level));
      return;
    }
    final created = await showCertificationLevelDialog(
      context,
      agencyId: agency,
    );
    if (!mounted) return;
    setState(() => _levelRevision++);
    if (created != null && !_session.isDisposed) {
      _setRows(setCredentialLevel(_rows, i, created.id));
    }
  }

  Widget _credentialRow(
    BuildContext context,
    List<CertificationCredential> rows,
    int i,
  ) {
    final l10n = context.l10n;
    final catalog = context.certificationCatalog;
    final agency = rows[i].agency;
    final level = rows[i].level;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CertificationAgencyDropdown(
                key: ValueKey('cert-edit-agency-$i'),
                value: agency,
                labelText: l10n.certifications_edit_label_agency,
                isDense: true,
                onChanged: (value) => _setRows(
                  setCredentialAgency(_rows, i, value, catalog: catalog),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CertificationOption>(
                // The key forces a remount when the agency changes or the
                // level is reset, so initialValue is read again.
                key: ValueKey(
                  'cert-edit-level-$i-$agency-$level-$_levelRevision',
                ),
                initialValue: CertificationOption.value(level),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.certifications_edit_label_certification,
                  prefixIcon: const Icon(Icons.workspace_premium),
                  isDense: true,
                ),
                items: certificationLevelItems(context, catalog, agency, level),
                onChanged: (option) => _onLevelChanged(i, agency, option),
              ),
            ],
          ),
        ),
        if (rows.length > 1)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.certifications_edit_removeRecognition,
            onPressed: () => _setRows(removeCredential(_rows, i)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
    // Whether a title only repeats its credentials follows the catalog,
    // which can arrive, or change on a sync, after the editor opens. A title
    // typed in this sitting is left as typed.
    ref.listen(certificationCatalogSyncProvider, (_, _) {
      if (!_titleTyped) _title.reformat();
    });
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final rows = _rows;
        final working = _session.working;
        final missing = !certificationHasTitleOrLevel(working);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _credentialRow(context, rows, i),
              const SizedBox(height: 16),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('cert-edit-add-recognition'),
                onPressed: () => _setRows([
                  ..._rows,
                  CertificationCredential(agency: _rows.first.agency),
                ]),
                icon: const Icon(Icons.add),
                label: Text(l10n.certifications_edit_addRecognition),
              ),
            ),
            const SizedBox(height: 16),
            // Optional: blank uses the derived title, which the hint shows.
            TextField(
              key: const ValueKey('cert-edit-title'),
              controller: _title.controller,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.certifications_edit_label_title,
                prefixIcon: const Icon(Icons.card_membership),
                hintText: derivedCertificationTitleL10n(
                  working.agency,
                  working.level,
                  l10n,
                  catalog: context.certificationCatalog,
                ),
                helperText: l10n.certifications_edit_helper_title,
                errorText: missing
                    ? l10n.certifications_edit_validation_certificationOrTitleRequired
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('cert-edit-card-number'),
              controller: _cardNumber.controller,
              decoration: InputDecoration(
                labelText: l10n.certifications_edit_label_cardNumber,
                prefixIcon: const Icon(Icons.numbers),
                hintText: l10n.certifications_edit_hint_cardNumber,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dates: issued and expires.
class CertificationDatesCardEditor extends StatelessWidget {
  const CertificationDatesCardEditor({super.key, required this.session});

  final EditSession<Certification> session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CertificationDatePickerField(
            key: const ValueKey('cert-edit-issue-date'),
            label: l10n.certifications_edit_label_issueDate,
            value: session.valueOf(certificationIssueDateField),
            icon: Icons.event_available,
            onChanged: (date) => session.set(certificationIssueDateField, date),
          ),
          const SizedBox(height: 16),
          CertificationDatePickerField(
            key: const ValueKey('cert-edit-expiry-date'),
            label: l10n.certifications_edit_label_expiryDate,
            value: session.valueOf(certificationExpiryDateField),
            icon: Icons.event_busy,
            helpText: l10n.certifications_edit_help_expiryDate,
            onChanged: (date) =>
                session.set(certificationExpiryDateField, date),
          ),
        ],
      ),
    );
  }
}

/// Instructor: a buddy picked, and the name and number on the card.
class CertificationInstructorCardEditor extends StatelessWidget {
  const CertificationInstructorCardEditor({super.key, required this.session});

  final EditSession<Certification> session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InstructorCardEditor<Certification>(
      session: session,
      field: certificationInstructorField,
      nameLabel: l10n.certifications_edit_label_instructorName,
      nameHint: l10n.certifications_edit_hint_instructorName,
      numberLabel: l10n.certifications_edit_label_instructorNumber,
      numberHint: l10n.certifications_edit_hint_instructorNumber,
      keyPrefix: 'cert-edit',
    );
  }
}

/// Card photos: front and back.
class CertificationCardPhotosEditor extends StatelessWidget {
  const CertificationCardPhotosEditor({
    super.key,
    required this.session,
    this.pickPhoto,
  });

  final EditSession<Certification> session;

  /// Picks a photo: the platform picker when null, a test's own otherwise.
  final Future<Uint8List?> Function(BuildContext context)? pickPhoto;

  Future<void> _pick(
    BuildContext context,
    EditField<Certification, Uint8List?> field,
  ) async {
    final pick = pickPhoto ?? pickCertificationCardPhoto;
    final bytes = await pick(context);
    if (bytes != null && !session.isDisposed) session.set(field, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget side(EditField<Certification, Uint8List?> field, String label) =>
        CertificationPhotoCard(
          label: label,
          imageData: session.valueOf(field),
          onPick: () => _pick(context, field),
          onDelete: () => session.set(field, null),
        );
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: side(
              certificationPhotoFrontField,
              l10n.certifications_detail_photoLabel_front,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: side(
              certificationPhotoBackField,
              l10n.certifications_detail_photoLabel_back,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notes, as Markdown.
class CertificationNotesCardEditor extends StatefulWidget {
  const CertificationNotesCardEditor({
    super.key,
    required this.session,
    this.autofocus = true,
  });

  final EditSession<Certification> session;

  /// Takes the focus as it opens: the open card's one field. Not in a
  /// dialog that lists every card, where it would scroll past the rest.
  final bool autofocus;

  @override
  State<CertificationNotesCardEditor> createState() =>
      _CertificationNotesCardEditorState();
}

class _CertificationNotesCardEditorState
    extends State<CertificationNotesCardEditor> {
  late final _binding = _bindText<String>(
    widget.session,
    certificationNotesField,
    (v) => v,
  );

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MarkdownNotesField(
    controller: _binding.controller,
    autofocus: widget.autofocus,
    decoration: InputDecoration(
      labelText: context.l10n.certifications_edit_label_notes,
      hintText: context.l10n.certifications_edit_hint_notes,
      alignLabelWithHint: true,
    ),
    maxLines: 4,
  );
}
