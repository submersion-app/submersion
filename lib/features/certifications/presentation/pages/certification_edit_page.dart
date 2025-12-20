import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../domain/entities/certification.dart';
import '../providers/certification_providers.dart';

class CertificationEditPage extends ConsumerStatefulWidget {
  final String? certificationId;

  const CertificationEditPage({super.key, this.certificationId});

  @override
  ConsumerState<CertificationEditPage> createState() =>
      _CertificationEditPageState();
}

class _CertificationEditPageState extends ConsumerState<CertificationEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _instructorNameController = TextEditingController();
  final _instructorNumberController = TextEditingController();
  final _notesController = TextEditingController();

  CertificationAgency _agency = CertificationAgency.padi;
  CertificationLevel? _level;
  DateTime? _issueDate;
  DateTime? _expiryDate;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  Certification? _originalCertification;

  bool get isEditing => widget.certificationId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadCertification();
    }
    _nameController.addListener(_onFieldChanged);
    _cardNumberController.addListener(_onFieldChanged);
    _instructorNameController.addListener(_onFieldChanged);
    _instructorNumberController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadCertification() async {
    setState(() => _isLoading = true);
    try {
      final cert = await ref
          .read(certificationRepositoryProvider)
          .getCertificationById(widget.certificationId!);
      if (cert != null && mounted) {
        _originalCertification = cert;
        _nameController.text = cert.name;
        _cardNumberController.text = cert.cardNumber ?? '';
        _instructorNameController.text = cert.instructorName ?? '';
        _instructorNumberController.text = cert.instructorNumber ?? '';
        _notesController.text = cert.notes;
        setState(() {
          _agency = cert.agency;
          _level = cert.level;
          _issueDate = cert.issueDate;
          _expiryDate = cert.expiryDate;
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading certification: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _instructorNameController.dispose();
    _instructorNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showDiscardDialog();
        if (shouldPop == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Certification' : 'Add Certification'),
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
                onPressed: _saveCertification,
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
                      // Certification name field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Certification Name *',
                          prefixIcon: Icon(Icons.card_membership),
                          hintText: 'e.g., Open Water Diver',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a certification name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Agency dropdown
                      DropdownButtonFormField<CertificationAgency>(
                        initialValue: _agency,
                        decoration: const InputDecoration(
                          labelText: 'Agency *',
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: CertificationAgency.values.map((agency) {
                          return DropdownMenuItem(
                            value: agency,
                            child: Text(agency.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _agency = value;
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Level dropdown
                      DropdownButtonFormField<CertificationLevel>(
                        initialValue: _level,
                        decoration: const InputDecoration(
                          labelText: 'Level',
                          prefixIcon: Icon(Icons.stairs),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Not specified'),
                          ),
                          ...CertificationLevel.values.map((level) {
                            return DropdownMenuItem(
                              value: level,
                              child: Text(level.displayName),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _level = value;
                            _hasChanges = true;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Card number field
                      TextFormField(
                        controller: _cardNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          prefixIcon: Icon(Icons.numbers),
                          hintText: 'Enter certification card number',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dates section header
                      Text(
                        'Dates',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Issue date picker
                      _DatePickerField(
                        label: 'Issue Date',
                        value: _issueDate,
                        icon: Icons.event_available,
                        onChanged: (date) {
                          setState(() {
                            _issueDate = date;
                            _hasChanges = true;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Expiry date picker
                      _DatePickerField(
                        label: 'Expiry Date',
                        value: _expiryDate,
                        icon: Icons.event_busy,
                        helpText: 'Leave empty for certifications that don\'t expire',
                        onChanged: (date) {
                          setState(() {
                            _expiryDate = date;
                            _hasChanges = true;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Instructor section header
                      Text(
                        'Instructor Information',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Instructor name field
                      TextFormField(
                        controller: _instructorNameController,
                        decoration: const InputDecoration(
                          labelText: 'Instructor Name',
                          prefixIcon: Icon(Icons.person),
                          hintText: 'Name of certifying instructor',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // Instructor number field
                      TextFormField(
                        controller: _instructorNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Instructor Number',
                          prefixIcon: Icon(Icons.badge),
                          hintText: 'Instructor certification number',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card photos section
                      Text(
                        'Card Photos',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Photo support coming in v2.0',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Notes section header
                      Text(
                        'Notes',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Notes field
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.notes),
                          hintText: 'Any additional notes',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      FilledButton(
                        onPressed: _isSaving ? null : _saveCertification,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isEditing
                                ? 'Update Certification'
                                : 'Add Certification',),
                      ),

                      // Cancel button
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _confirmCancel(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    if (_hasChanges) {
      final discard = await _showDiscardDialog();
      if (discard == true && mounted) {
        context.pop();
      }
    } else {
      context.pop();
    }
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave?',),
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

  Future<void> _saveCertification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get the current diver ID - preserve existing for edits, get fresh for new certs
      final diverId = _originalCertification?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final now = DateTime.now();
      final cert = Certification(
        id: widget.certificationId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        agency: _agency,
        level: _level,
        cardNumber: _cardNumberController.text.trim().isEmpty
            ? null
            : _cardNumberController.text.trim(),
        issueDate: _issueDate,
        expiryDate: _expiryDate,
        instructorName: _instructorNameController.text.trim().isEmpty
            ? null
            : _instructorNameController.text.trim(),
        instructorNumber: _instructorNumberController.text.trim().isEmpty
            ? null
            : _instructorNumberController.text.trim(),
        photoFrontPath: _originalCertification?.photoFrontPath,
        photoBackPath: _originalCertification?.photoBackPath,
        notes: _notesController.text.trim(),
        createdAt: _originalCertification?.createdAt ?? now,
        updatedAt: now,
      );

      if (isEditing) {
        await ref
            .read(certificationListNotifierProvider.notifier)
            .updateCertification(cert);
      } else {
        await ref
            .read(certificationListNotifierProvider.notifier)
            .addCertification(cert);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Certification updated successfully'
                : 'Certification added successfully',),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving certification: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final IconData icon;
  final String? helpText;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.icon,
    this.helpText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _pickDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              suffixIcon: value != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onChanged(null),
                    )
                  : const Icon(Icons.calendar_today),
            ),
            child: Text(
              value != null
                  ? DateFormat.yMMMd().format(value!)
                  : 'Tap to select',
              style: TextStyle(
                color: value != null
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              helpText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
