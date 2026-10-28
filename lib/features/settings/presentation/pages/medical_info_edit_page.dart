import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

class MedicalInfoEditPage extends ConsumerStatefulWidget {
  const MedicalInfoEditPage({super.key});

  @override
  ConsumerState<MedicalInfoEditPage> createState() =>
      _MedicalInfoEditPageState();
}

class _MedicalInfoEditPageState extends ConsumerState<MedicalInfoEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _bloodTypeCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();

  bool _populated = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bloodTypeCtrl.addListener(_onFieldChanged);
    _allergiesCtrl.addListener(_onFieldChanged);
    _medicationsCtrl.addListener(_onFieldChanged);
    _medicalNotesCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _bloodTypeCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicationsCtrl.dispose();
    _medicalNotesCtrl.dispose();
    super.dispose();
  }

  void _populateFromDiver(Diver diver) {
    if (_populated) return;
    _populated = true;
    _bloodTypeCtrl.text = diver.bloodType ?? '';
    _allergiesCtrl.text = diver.allergies ?? '';
    _medicationsCtrl.text = diver.medications ?? '';
    _medicalNotesCtrl.text = diver.medicalNotes;
    _hasChanges = false;
  }

  String? _trimOrNull(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save(Diver existingDiver) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updated = existingDiver.copyWith(
        bloodType: _trimOrNull(_bloodTypeCtrl),
        allergies: _trimOrNull(_allergiesCtrl),
        medications: _trimOrNull(_medicationsCtrl),
        medicalNotes: _medicalNotesCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );
      await ref.read(diverListNotifierProvider.notifier).updateDiver(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settings_profileHub_saved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.divers_edit_errorSaving('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.divers_edit_discardDialogTitle),
        content: Text(context.l10n.divers_edit_discardDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.divers_edit_keepEditingButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.divers_edit_discardButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diverAsync = ref.watch(currentDiverProvider);

    return diverAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settings_profileHub_medicalInfo),
        ),
        body: Center(child: Text('$error')),
      ),
      data: (diver) {
        if (diver == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.settings_profileHub_medicalInfo),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        _populateFromDiver(diver);
        return _buildScaffold(diver);
      },
    );
  }

  Widget _buildScaffold(Diver diver) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settings_profileHub_medicalInfo),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              AppBarTextAction(
                label: context.l10n.divers_edit_saveButton,
                onPressed: () => _save(diver),
              ),
          ],
        ),
        body: SingleChildScrollView(
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
                            labelText:
                                context.l10n.divers_edit_medicationsLabel,
                            prefixIcon: const Icon(Icons.medication),
                            hintText: context.l10n.divers_edit_medicationsHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MarkdownNotesField(
                          controller: _medicalNotesCtrl,
                          decoration: InputDecoration(
                            labelText:
                                context.l10n.divers_edit_medicalNotesLabel,
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
              // Clearances are documents with an expiry (issue #2613).
              const _MedicalClearancesCard(),
            ],
          ),
        ),
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
