import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

  DateTime? _medicalClearanceExpiry;
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
    _medicalClearanceExpiry = diver.medicalClearanceExpiryDate;
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
        medicalClearanceExpiryDate: _medicalClearanceExpiry,
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

  Future<void> _selectMedicalClearanceExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _medicalClearanceExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _medicalClearanceExpiry = picked;
        _hasChanges = true;
      });
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
              TextButton(
                onPressed: () => _save(diver),
                child: Text(context.l10n.divers_edit_saveButton),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
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
                    _buildMedicalClearanceField(),
                    const SizedBox(height: 16),
                    TextFormField(
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
        ),
      ),
    );
  }

  Widget _buildMedicalClearanceField() {
    final isExpired =
        _medicalClearanceExpiry != null &&
        DateTime.now().isAfter(_medicalClearanceExpiry!);
    final isExpiringSoon =
        _medicalClearanceExpiry != null &&
        !isExpired &&
        _medicalClearanceExpiry!.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.verified_user),
      title: Text(context.l10n.divers_edit_medicalClearanceTitle),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              _medicalClearanceExpiry != null
                  ? DateFormat.yMMMd().format(_medicalClearanceExpiry!)
                  : context.l10n.divers_edit_medicalClearanceNotSet,
            ),
          ),
          if (isExpired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.divers_edit_medicalClearanceExpired,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            )
          else if (isExpiringSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.divers_edit_medicalClearanceExpiringSoon,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_medicalClearanceExpiry != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: context.l10n.divers_edit_clearMedicalClearanceTooltip,
              onPressed: () {
                setState(() {
                  _medicalClearanceExpiry = null;
                  _hasChanges = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            tooltip: context.l10n.divers_edit_selectMedicalClearanceTooltip,
            onPressed: _selectMedicalClearanceExpiry,
          ),
        ],
      ),
    );
  }
}
