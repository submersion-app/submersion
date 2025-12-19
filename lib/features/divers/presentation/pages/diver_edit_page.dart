import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/diver.dart';
import '../providers/diver_providers.dart';

class DiverEditPage extends ConsumerStatefulWidget {
  final String? diverId;

  const DiverEditPage({super.key, this.diverId});

  @override
  ConsumerState<DiverEditPage> createState() => _DiverEditPageState();
}

class _DiverEditPageState extends ConsumerState<DiverEditPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal info controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Emergency contact controllers
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  // Medical info controllers
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicalNotesController = TextEditingController();

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
    _bloodTypeController.addListener(_onFieldChanged);
    _allergiesController.addListener(_onFieldChanged);
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
      final diver = await ref.read(diverRepositoryProvider).getDiverById(widget.diverId!);
      if (diver != null && mounted) {
        _originalDiver = diver;
        _nameController.text = diver.name;
        _emailController.text = diver.email ?? '';
        _phoneController.text = diver.phone ?? '';
        _emergencyNameController.text = diver.emergencyContact.name ?? '';
        _emergencyPhoneController.text = diver.emergencyContact.phone ?? '';
        _emergencyRelationController.text = diver.emergencyContact.relation ?? '';
        _bloodTypeController.text = diver.bloodType ?? '';
        _allergiesController.text = diver.allergies ?? '';
        _medicalNotesController.text = diver.medicalNotes;
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
          SnackBar(content: Text('Error loading diver: $e')),
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
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicalNotesController.dispose();
    _insuranceProviderController.dispose();
    _insurancePolicyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(isEditing ? 'Edit Diver' : 'Add Diver'),
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
                child: const Text('Save'),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Personal Info Section
                      _buildSectionHeader(context, 'Personal Information'),
                      _buildPersonalInfoSection(),
                      const SizedBox(height: 24),

                      // Emergency Contact Section
                      _buildSectionHeader(context, 'Emergency Contact'),
                      _buildEmergencyContactSection(),
                      const SizedBox(height: 24),

                      // Medical Info Section
                      _buildSectionHeader(context, 'Medical Information'),
                      _buildMedicalInfoSection(),
                      const SizedBox(height: 24),

                      // Insurance Section
                      _buildSectionHeader(context, 'Dive Insurance'),
                      _buildInsuranceSection(),
                      const SizedBox(height: 24),

                      // Notes Section
                      _buildSectionHeader(context, 'Notes'),
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
                            : Text(isEditing ? 'Update Diver' : 'Add Diver'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
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
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Enter a valid email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyRelationController,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.people),
                hintText: 'e.g., Spouse, Parent, Friend',
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
              decoration: const InputDecoration(
                labelText: 'Blood Type',
                prefixIcon: Icon(Icons.bloodtype),
                hintText: 'e.g., O+, A-, B+',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _allergiesController,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                prefixIcon: Icon(Icons.warning_amber),
                hintText: 'e.g., Penicillin, Shellfish',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicalNotesController,
              decoration: const InputDecoration(
                labelText: 'Medical Notes',
                prefixIcon: Icon(Icons.medical_information),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _insuranceProviderController,
              decoration: const InputDecoration(
                labelText: 'Insurance Provider',
                prefixIcon: Icon(Icons.verified_user),
                hintText: 'e.g., DAN, DiveAssure',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _insurancePolicyController,
              decoration: const InputDecoration(
                labelText: 'Policy Number',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Expiry Date'),
              subtitle: Text(
                _insuranceExpiry != null
                    ? DateFormat.yMMMd().format(_insuranceExpiry!)
                    : 'Not set',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_insuranceExpiry != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _insuranceExpiry = null;
                          _hasChanges = true;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar),
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
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes),
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
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
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
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
        bloodType: _bloodTypeController.text.trim().isEmpty
            ? null
            : _bloodTypeController.text.trim(),
        allergies: _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        medicalNotes: _medicalNotesController.text.trim(),
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

      if (isEditing) {
        await ref.read(diverListNotifierProvider.notifier).updateDiver(diver);
      } else {
        await ref.read(diverListNotifierProvider.notifier).addDiver(diver);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Diver updated' : 'Diver added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving diver: $e')),
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
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
