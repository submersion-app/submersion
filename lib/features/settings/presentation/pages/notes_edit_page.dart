import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// The active diver's own notes, on the shared Cancel and Save bar (issue
/// #4527, phase 4).
class NotesEditPage extends ConsumerStatefulWidget {
  const NotesEditPage({super.key});

  @override
  ConsumerState<NotesEditPage> createState() => _NotesEditPageState();
}

class _NotesEditPageState extends ConsumerState<NotesEditPage>
    with
        RecordEditorHost<NotesEditPage, DiverNotesDraft>,
        DiverProfileEditor<NotesEditPage, DiverNotesDraft> {
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesCtrl.addListener(editorChanged);
    openProfileEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  String editorTitle(BuildContext context) =>
      context.l10n.settings_profileHub_notes;

  @override
  DiverNotesDraft readEditorDraft() => (notes: _notesCtrl.text);

  /// Notes take anything.
  @override
  bool validateEditor() => true;

  @override
  void fillFromDiver(Diver diver) => _notesCtrl.text = diver.notes;

  @override
  Diver applyEditorDraft(
    Diver stored,
    DiverNotesDraft start,
    DiverNotesDraft draft,
  ) => applyDiverNotesDraft(stored, start, draft);

  @override
  Widget build(BuildContext context) {
    return profileScaffold(
      context,
      form: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownNotesField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_notesLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              maxLines: 10,
            ),
          ),
        ),
      ),
    );
  }
}
