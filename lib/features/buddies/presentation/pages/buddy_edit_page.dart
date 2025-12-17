import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/buddy.dart';
import '../providers/buddy_providers.dart';

class BuddyEditPage extends ConsumerStatefulWidget {
  final String? buddyId;
  final String? initialName;
  final String? initialEmail;
  final String? initialPhone;

  const BuddyEditPage({
    super.key,
    this.buddyId,
    this.initialName,
    this.initialEmail,
    this.initialPhone,
  });

  @override
  ConsumerState<BuddyEditPage> createState() => _BuddyEditPageState();
}

class _BuddyEditPageState extends ConsumerState<BuddyEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  CertificationLevel? _certLevel;
  CertificationAgency? _certAgency;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  Buddy? _originalBuddy;

  bool get isEditing => widget.buddyId != null;
  bool get hasInitialData =>
      widget.initialName != null ||
      widget.initialEmail != null ||
      widget.initialPhone != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadBuddy();
    } else if (hasInitialData) {
      // Pre-fill from imported contact
      _nameController.text = widget.initialName ?? '';
      _emailController.text = widget.initialEmail ?? '';
      _phoneController.text = widget.initialPhone ?? '';
      // Mark as having changes since we have pre-filled data
      _hasChanges = true;
    }
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadBuddy() async {
    setState(() => _isLoading = true);
    try {
      final buddy =
          await ref.read(buddyRepositoryProvider).getBuddyById(widget.buddyId!);
      if (buddy != null && mounted) {
        _originalBuddy = buddy;
        _nameController.text = buddy.name;
        _emailController.text = buddy.email ?? '';
        _phoneController.text = buddy.phone ?? '';
        _notesController.text = buddy.notes;
        setState(() {
          _certLevel = buddy.certificationLevel;
          _certAgency = buddy.certificationAgency;
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading buddy: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Buddy' : 'Add Buddy'),
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
                onPressed: _saveBuddy,
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
                      // Profile photo placeholder
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                _nameController.text.isNotEmpty
                                    ? _getInitials(_nameController.text)
                                    : '?',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Photo support coming in v2.0',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          prefixIcon: Icon(Icons.person),
                          hintText: 'Enter buddy name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          hintText: 'email@example.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                          hintText: '+1 234 567 8900',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),

                      // Certification section header
                      Text(
                        'Certification',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Certification level dropdown
                      DropdownButtonFormField<CertificationLevel>(
                        value: _certLevel,
                        decoration: const InputDecoration(
                          labelText: 'Certification Level',
                          prefixIcon: Icon(Icons.card_membership),
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
                            _certLevel = value;
                            _hasChanges = true;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Certification agency dropdown
                      DropdownButtonFormField<CertificationAgency>(
                        value: _certAgency,
                        decoration: const InputDecoration(
                          labelText: 'Certification Agency',
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Not specified'),
                          ),
                          ...CertificationAgency.values.map((agency) {
                            return DropdownMenuItem(
                              value: agency,
                              child: Text(agency.displayName),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _certAgency = value;
                            _hasChanges = true;
                          });
                        },
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
                          hintText: 'Any additional notes about this buddy',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      FilledButton(
                        onPressed: _isSaving ? null : _saveBuddy,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Update Buddy' : 'Add Buddy'),
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      return await _showDiscardDialog() ?? false;
    }
    return true;
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
        content:
            const Text('You have unsaved changes. Are you sure you want to leave?'),
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

  Future<void> _saveBuddy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final buddy = Buddy(
        id: widget.buddyId ?? '',
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        certificationLevel: _certLevel,
        certificationAgency: _certAgency,
        photoPath: _originalBuddy?.photoPath,
        notes: _notesController.text.trim(),
        createdAt: _originalBuddy?.createdAt ?? now,
        updatedAt: now,
      );

      Buddy savedBuddy;
      if (isEditing) {
        await ref.read(buddyListNotifierProvider.notifier).updateBuddy(buddy);
        savedBuddy = buddy;
      } else {
        savedBuddy = await ref.read(buddyListNotifierProvider.notifier).addBuddy(buddy);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Buddy updated successfully'
                : 'Buddy added successfully'),
          ),
        );
        // Return the saved buddy so callers can use it
        context.pop(savedBuddy);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving buddy: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
