import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

class MedicalInfoEditPage extends ConsumerStatefulWidget {
  const MedicalInfoEditPage({super.key});

  @override
  ConsumerState<MedicalInfoEditPage> createState() =>
      _MedicalInfoEditPageState();
}

class _MedicalInfoEditPageState extends ConsumerState<MedicalInfoEditPage>
    with
        RecordEditorHost<MedicalInfoEditPage, MedicalInfoDraft>,
        DiverProfileEditor<MedicalInfoEditPage, MedicalInfoDraft> {
  final _formKey = GlobalKey<FormState>();
  final _bloodTypeCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();

  List<TextEditingController> get _controllers => [
    _bloodTypeCtrl,
    _allergiesCtrl,
    _medicationsCtrl,
    _medicalNotesCtrl,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(editorChanged);
    }
    openProfileEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  String editorTitle(BuildContext context) =>
      context.l10n.settings_profileHub_medicalInfo;

  @override
  MedicalInfoDraft readEditorDraft() => (
    bloodType: _bloodTypeCtrl.text,
    allergies: _allergiesCtrl.text,
    medications: _medicationsCtrl.text,
    medicalNotes: _medicalNotesCtrl.text,
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  void fillFromDiver(Diver diver) {
    _bloodTypeCtrl.text = diver.bloodType ?? '';
    _allergiesCtrl.text = diver.allergies ?? '';
    _medicationsCtrl.text = diver.medications ?? '';
    _medicalNotesCtrl.text = diver.medicalNotes;
  }

  @override
  Diver applyEditorDraft(
    Diver stored,
    MedicalInfoDraft start,
    MedicalInfoDraft draft,
  ) => applyMedicalInfoDraft(stored, start, draft);

  @override
  Widget build(BuildContext context) =>
      profileScaffold(context, form: _buildForm);

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _bloodTypeCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_bloodTypeLabel,
                        prefixIcon: const Icon(Icons.bloodtype),
                        hintText: context.l10n.divers_edit_bloodTypeHint,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _allergiesCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_allergiesLabel,
                        prefixIcon: const Icon(Icons.warning_amber),
                        hintText: context.l10n.divers_edit_allergiesHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _medicationsCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_medicationsLabel,
                        prefixIcon: const Icon(Icons.medication),
                        hintText: context.l10n.divers_edit_medicationsHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    MarkdownNotesField(
                      controller: _medicalNotesCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_medicalNotesLabel,
                        prefixIcon: const Icon(Icons.medical_information),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Clearances are documents with an expiry (issue #2613). One
          // added here is its own record, saved at once (pattern, "Not
          // held"); the medical edits stay underneath meanwhile.
          const _MedicalClearancesCard(),
        ],
      ),
    );
  }
}

/// The diver's medical clearance documents, each with its expiry badge,
/// and a way to add one.
class _MedicalClearancesCard extends ConsumerWidget {
  const _MedicalClearancesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final docs = ref.watch(
      documentsForOwnerProvider(const DocumentOwner.personal()),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.documents_medical_clearances,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.documents_medical_addClearance),
                  onPressed: () =>
                      context.push('/documents/new?type=medicalClearance'),
                ),
              ],
            ),
            docs.when(
              data: (list) {
                final clearances = [
                  for (final d in list)
                    if (d.type == DocumentType.medicalClearance) d,
                ];
                if (clearances.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.documents_medical_clearancesEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final d in clearances)
                      DocumentTile(
                        document: d,
                        onTap: () => context.push('/documents/${d.id}'),
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(l10n.documents_error_load('$e')),
            ),
          ],
        ),
      ),
    );
  }
}
