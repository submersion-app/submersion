import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

class DiverEditPage extends ConsumerStatefulWidget {
  final String? diverId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when save completes (pass the saved item ID).
  final void Function(String savedId)? onSaved;

  /// Callback when user cancels editing.
  final VoidCallback? onCancel;

  const DiverEditPage({
    super.key,
    this.diverId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

  @override
  ConsumerState<DiverEditPage> createState() => _DiverEditPageState();
}

class _DiverEditPageState extends ConsumerState<DiverEditPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal info controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Primary emergency contact controllers
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  // Secondary emergency contact controllers
  final _emergency2NameController = TextEditingController();
  final _emergency2PhoneController = TextEditingController();
  final _emergency2RelationController = TextEditingController();

  // Medical info controllers
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  DateTime? _medicalClearanceExpiry;

  // Insurance controllers
  final _insuranceProviderController = TextEditingController();
  final _insurancePolicyController = TextEditingController();
  DateTime? _insuranceExpiry;

  // Notes controller
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  Diver? _originalDiver;

  bool get isEditing => widget.diverId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadDiver();
    }
    _addListeners();
  }

  void _addListeners() {
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emergencyNameController.addListener(_onFieldChanged);
    _emergencyPhoneController.addListener(_onFieldChanged);
    _emergencyRelationController.addListener(_onFieldChanged);
    _emergency2NameController.addListener(_onFieldChanged);
    _emergency2PhoneController.addListener(_onFieldChanged);
    _emergency2RelationController.addListener(_onFieldChanged);
    _bloodTypeController.addListener(_onFieldChanged);
    _allergiesController.addListener(_onFieldChanged);
    _medicationsController.addListener(_onFieldChanged);
    _medicalNotesController.addListener(_onFieldChanged);
    _insuranceProviderController.addListener(_onFieldChanged);
    _insurancePolicyController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadDiver() async {
    setState(() => _isLoading = true);
    try {
      final diver = await ref
          .read(diverRepositoryProvider)
          .getDiverById(widget.diverId!);
      if (diver != null && mounted) {
        _originalDiver = diver;
        _nameController.text = diver.name;
        _emailController.text = diver.email ?? '';
        _phoneController.text = diver.phone ?? '';
        // Primary emergency contact
        _emergencyNameController.text = diver.emergencyContact.name ?? '';
        _emergencyPhoneController.text = diver.emergencyContact.phone ?? '';
        _emergencyRelationController.text =
            diver.emergencyContact.relation ?? '';
        // Secondary emergency contact
        _emergency2NameController.text = diver.emergencyContact2.name ?? '';
        _emergency2PhoneController.text = diver.emergencyContact2.phone ?? '';
        _emergency2RelationController.text =
            diver.emergencyContact2.relation ?? '';
        // Medical info
        _bloodTypeController.text = diver.bloodType ?? '';
        _allergiesController.text = diver.allergies ?? '';
        _medicationsController.text = diver.medications ?? '';
        _medicalNotesController.text = diver.medicalNotes;
        _medicalClearanceExpiry = diver.medicalClearanceExpiryDate;
        // Insurance
        _insuranceProviderController.text = diver.insurance.provider ?? '';
        _insurancePolicyController.text = diver.insurance.policyNumber ?? '';
        _insuranceExpiry = diver.insurance.expiryDate;
        _notesController.text = diver.notes;
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.divers_edit_errorLoading('$e'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _emergency2NameController.dispose();
    _emergency2PhoneController.dispose();
    _emergency2RelationController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _medicalNotesController.dispose();
    _insuranceProviderController.dispose();
    _insurancePolicyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Personal Info Section
                  _buildSectionHeader(
                    context,
                    context.l10n.divers_edit_personalInfoSection,
                  ),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 24),

                  // Emergency Contacts Section
                  _buildSectionHeader(
                    context,
                    context.l10n.divers_edit_emergencyContactsSection,
                  ),
                  _buildEmergencyContactSection(
                    context.l10n.divers_edit_primaryContactTitle,
                  ),
                  const SizedBox(height: 12),
                  _buildSecondaryEmergencyContactSection(),
                  const SizedBox(height: 24),

                  // Medical Info Section
                  _buildSectionHeader(
                    context,
                    context.l10n.divers_edit_medicalInfoSection,
                  ),
                  _buildMedicalInfoSection(),
                  const SizedBox(height: 24),

                  // Insurance Section
                  _buildSectionHeader(
                    context,
                    context.l10n.divers_edit_insuranceSection,
                  ),
                  _buildInsuranceSection(),
                  const SizedBox(height: 24),

                  // Notes Section
                  _buildSectionHeader(
                    context,
                    context.l10n.divers_edit_notesSection,
                  ),
                  _buildNotesSection(),
                  const SizedBox(height: 32),

                  // Save Button
                  FilledButton(
                    onPressed: _isSaving ? null : _saveDiver,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing
                                ? context.l10n.divers_edit_updateButton
                                : context.l10n.divers_edit_addButton,
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );

    // Embedded mode: no Scaffold wrapper
    if (widget.embedded) {
      return PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && _hasChanges) {
            final shouldDiscard = await _showDiscardDialog();
            if (shouldDiscard == true) {
              widget.onCancel?.call();
            }
          }
        },
        child: Column(
          children: [
            _buildEmbeddedHeader(context),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Full page mode with Scaffold
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing
                ? context.l10n.divers_edit_editTitle
                : context.l10n.divers_edit_addTitle,
          ),
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
                onPressed: _saveDiver,
                child: Text(context.l10n.divers_edit_saveButton),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.person_add,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? context.l10n.divers_edit_editTitle
                  : context.l10n.divers_edit_addTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            TextButton(
              onPressed: _handleCancel,
              child: Text(context.l10n.divers_edit_cancelButton),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saveDiver,
              child: Text(context.l10n.divers_edit_saveButton),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCancel() async {
    if (_hasChanges) {
      final shouldDiscard = await _showDiscardDialog();
      if (shouldDiscard == true) {
        widget.onCancel?.call();
      }
    } else {
      widget.onCancel?.call();
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_nameLabel,
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.divers_edit_nameError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_emailLabel,
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@') || !value.contains('.')) {
                    return context.l10n.divers_edit_emailError;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_phoneLabel,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactSection(String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyNameController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactPhoneLabel,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyRelationController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_relationshipLabel,
                prefixIcon: const Icon(Icons.people),
                hintText: context.l10n.divers_edit_relationshipHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryEmergencyContactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.divers_edit_secondaryContactTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergency2NameController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergency2PhoneController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactPhoneLabel,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergency2RelationController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_relationshipLabel,
                prefixIcon: const Icon(Icons.people),
                hintText: context.l10n.divers_edit_relationshipHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _bloodTypeController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_bloodTypeLabel,
                prefixIcon: const Icon(Icons.bloodtype),
                hintText: context.l10n.divers_edit_bloodTypeHint,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _allergiesController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_allergiesLabel,
                prefixIcon: const Icon(Icons.warning_amber),
                hintText: context.l10n.divers_edit_allergiesHint,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicationsController,
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
              controller: _medicalNotesController,
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

  Future<void> _selectMedicalClearanceExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _medicalClearanceExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _medicalClearanceExpiry = picked;
        _hasChanges = true;
      });
    }
  }

  Widget _buildInsuranceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _insuranceProviderController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_insuranceProviderLabel,
                prefixIcon: const Icon(Icons.verified_user),
                hintText: context.l10n.divers_edit_insuranceProviderHint,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _insurancePolicyController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_policyNumberLabel,
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(context.l10n.divers_edit_expiryDateTitle),
              subtitle: Text(
                _insuranceExpiry != null
                    ? DateFormat.yMMMd().format(_insuranceExpiry!)
                    : context.l10n.divers_edit_expiryDateNotSet,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_insuranceExpiry != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip:
                          context.l10n.divers_edit_clearInsuranceExpiryTooltip,
                      onPressed: () {
                        setState(() {
                          _insuranceExpiry = null;
                          _hasChanges = true;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    tooltip:
                        context.l10n.divers_edit_selectInsuranceExpiryTooltip,
                    onPressed: _selectInsuranceExpiry,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: context.l10n.divers_edit_notesLabel,
            prefixIcon: const Icon(Icons.notes),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
      ),
    );
  }

  Future<void> _selectInsuranceExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _insuranceExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _insuranceExpiry = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveDiver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final diver = Diver(
        id: _originalDiver?.id ?? '',
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        emergencyContact: EmergencyContact(
          name: _emergencyNameController.text.trim().isEmpty
              ? null
              : _emergencyNameController.text.trim(),
          phone: _emergencyPhoneController.text.trim().isEmpty
              ? null
              : _emergencyPhoneController.text.trim(),
          relation: _emergencyRelationController.text.trim().isEmpty
              ? null
              : _emergencyRelationController.text.trim(),
        ),
        emergencyContact2: EmergencyContact(
          name: _emergency2NameController.text.trim().isEmpty
              ? null
              : _emergency2NameController.text.trim(),
          phone: _emergency2PhoneController.text.trim().isEmpty
              ? null
              : _emergency2PhoneController.text.trim(),
          relation: _emergency2RelationController.text.trim().isEmpty
              ? null
              : _emergency2RelationController.text.trim(),
        ),
        bloodType: _bloodTypeController.text.trim().isEmpty
            ? null
            : _bloodTypeController.text.trim(),
        allergies: _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        medications: _medicationsController.text.trim().isEmpty
            ? null
            : _medicationsController.text.trim(),
        medicalNotes: _medicalNotesController.text.trim(),
        medicalClearanceExpiryDate: _medicalClearanceExpiry,
        insurance: DiverInsurance(
          provider: _insuranceProviderController.text.trim().isEmpty
              ? null
              : _insuranceProviderController.text.trim(),
          policyNumber: _insurancePolicyController.text.trim().isEmpty
              ? null
              : _insurancePolicyController.text.trim(),
          expiryDate: _insuranceExpiry,
        ),
        notes: _notesController.text.trim(),
        isDefault: _originalDiver?.isDefault ?? false,
        createdAt: _originalDiver?.createdAt ?? now,
        updatedAt: now,
      );

      String savedId;
      if (isEditing) {
        await ref.read(diverListNotifierProvider.notifier).updateDiver(diver);
        savedId = diver.id;
      } else {
        final newDiver = await ref
            .read(diverListNotifierProvider.notifier)
            .addDiver(diver);
        savedId = newDiver.id;
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          context.pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? context.l10n.divers_edit_diverUpdated
                  : context.l10n.divers_edit_diverAdded,
            ),
          ),
        );
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
      builder: (context) => AlertDialog(
        title: Text(context.l10n.divers_edit_discardDialogTitle),
        content: Text(context.l10n.divers_edit_discardDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.divers_edit_keepEditingButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.divers_edit_discardButton),
          ),
        ],
      ),
    );
  }
}
