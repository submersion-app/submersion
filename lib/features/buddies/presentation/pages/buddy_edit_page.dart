import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_merge_form_controller.dart';

class BuddyEditPage extends ConsumerStatefulWidget {
  final String? buddyId;
  final String? initialName;
  final String? initialEmail;
  final String? initialPhone;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when save completes (pass the saved item ID).
  final void Function(String savedId)? onSaved;

  /// Callback when user cancels editing.
  final VoidCallback? onCancel;

  /// Loaded buddies to merge into one. Mutually exclusive with [buddyId].
  /// Data loading is handled by [BuddyMergePage].
  final List<Buddy>? mergeBuddies;

  const BuddyEditPage({
    super.key,
    this.buddyId,
    this.initialName,
    this.initialEmail,
    this.initialPhone,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.mergeBuddies,
  }) : assert(
         buddyId == null || mergeBuddies == null,
         'buddyId and mergeBuddies are mutually exclusive',
       );

  bool get isMerging => mergeBuddies != null && mergeBuddies!.length > 1;

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

  BuddyMergeFormController? _mergeCtrl;

  bool get isEditing => widget.buddyId != null;
  bool get hasInitialData =>
      widget.initialName != null ||
      widget.initialEmail != null ||
      widget.initialPhone != null;

  @override
  void initState() {
    super.initState();
    if (widget.isMerging) {
      _mergeCtrl = BuddyMergeFormController();
      _originalBuddy = widget.mergeBuddies!.first;
      final (:certLevel, :certAgency) = _mergeCtrl!.initialize(
        buddies: widget.mergeBuddies!,
        nameController: _nameController,
        emailController: _emailController,
        phoneController: _phoneController,
        notesController: _notesController,
      );
      _certLevel = certLevel;
      _certAgency = certAgency;
    } else if (isEditing) {
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
      final buddy = await ref
          .read(buddyRepositoryProvider)
          .getBuddyById(widget.buddyId!);
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
          SnackBar(
            content: Text(
              context.l10n.buddies_message_errorLoading(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Widget _buildMergeCycleButton(VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: context.l10n.buddies_edit_merge_fieldSourceCycleTooltip,
      icon: const Icon(Icons.sync_alt, size: 18),
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  InputDecoration _withMergeTextDecoration({
    required String key,
    required InputDecoration decoration,
  }) {
    final ctrl = _mergeCtrl;
    if (!widget.isMerging || ctrl == null) return decoration;

    final candidates = ctrl.textCandidates[key];
    if (candidates == null || candidates.length < 2) return decoration;

    final currentIndex = ctrl.fieldIndices[key] ?? 0;
    final current = candidates[currentIndex];
    final controller = switch (key) {
      'name' => _nameController,
      'email' => _emailController,
      'phone' => _phoneController,
      'notes' => _notesController,
      _ => _nameController,
    };

    return decoration.copyWith(
      helperText: context.l10n.buddies_edit_merge_fieldSourceLabel(
        current.buddyName,
        currentIndex + 1,
        candidates.length,
      ),
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _buildMergeCycleButton(
          () => setState(() {
            ctrl.cycleTextField(key, controller: controller);
            _hasChanges = true;
          }),
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 36),
    );
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
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildFormBody(context);

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

    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildFormBody(context);

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
            widget.isMerging
                ? context.l10n.buddies_edit_merge_title
                : isEditing
                ? context.l10n.buddies_title_edit
                : context.l10n.buddies_title_add,
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
                onPressed: _saveBuddy,
                child: Text(context.l10n.common_action_save),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    return SingleChildScrollView(
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      _nameController.text.isNotEmpty
                          ? _getInitials(_nameController.text)
                          : '?',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                context.l10n.buddies_label_photoComingSoon,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: _withMergeTextDecoration(
                key: 'name',
                decoration: InputDecoration(
                  labelText: context.l10n.buddies_field_nameRequired,
                  prefixIcon: const Icon(Icons.person),
                  hintText: context.l10n.buddies_field_nameHint,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.buddies_validation_nameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email field
            TextFormField(
              controller: _emailController,
              decoration: _withMergeTextDecoration(
                key: 'email',
                decoration: InputDecoration(
                  labelText: context.l10n.buddies_field_email,
                  prefixIcon: const Icon(Icons.email),
                  hintText: context.l10n.buddies_field_emailHint,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return context.l10n.buddies_validation_emailInvalid;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone field
            TextFormField(
              controller: _phoneController,
              decoration: _withMergeTextDecoration(
                key: 'phone',
                decoration: InputDecoration(
                  labelText: context.l10n.buddies_field_phone,
                  prefixIcon: const Icon(Icons.phone),
                  hintText: context.l10n.buddies_field_phoneHint,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Certification section header
            Text(
              context.l10n.buddies_section_certification,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Certification level dropdown
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CertificationLevel>(
                    key: ValueKey(_certLevel),
                    initialValue: _certLevel,
                    decoration: InputDecoration(
                      labelText: context.l10n.buddies_field_certificationLevel,
                      prefixIcon: const Icon(Icons.card_membership),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.l10n.buddies_label_notSpecified),
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
                ),
                if (widget.isMerging &&
                    _mergeCtrl != null &&
                    _mergeCtrl!.certLevelCandidates.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildMergeCycleButton(() {
                    setState(() {
                      _certLevel = _mergeCtrl!.cycleCertLevel();
                      _hasChanges = true;
                    });
                  }),
                ],
              ],
            ),
            if (widget.isMerging &&
                _mergeCtrl != null &&
                _mergeCtrl!.certLevelCandidates.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.buddies_edit_merge_fieldSourceLabel(
                  _mergeCtrl!
                      .certLevelCandidates[_mergeCtrl!
                              .fieldIndices['certLevel'] ??
                          0]
                      .buddyName,
                  (_mergeCtrl!.fieldIndices['certLevel'] ?? 0) + 1,
                  _mergeCtrl!.certLevelCandidates.length,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),

            // Certification agency dropdown
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CertificationAgency>(
                    key: ValueKey(_certAgency),
                    initialValue: _certAgency,
                    decoration: InputDecoration(
                      labelText: context.l10n.buddies_field_certificationAgency,
                      prefixIcon: const Icon(Icons.business),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.l10n.buddies_label_notSpecified),
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
                ),
                if (widget.isMerging &&
                    _mergeCtrl != null &&
                    _mergeCtrl!.certAgencyCandidates.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildMergeCycleButton(() {
                    setState(() {
                      _certAgency = _mergeCtrl!.cycleCertAgency();
                      _hasChanges = true;
                    });
                  }),
                ],
              ],
            ),
            if (widget.isMerging &&
                _mergeCtrl != null &&
                _mergeCtrl!.certAgencyCandidates.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.buddies_edit_merge_fieldSourceLabel(
                  _mergeCtrl!
                      .certAgencyCandidates[_mergeCtrl!
                              .fieldIndices['certAgency'] ??
                          0]
                      .buddyName,
                  (_mergeCtrl!.fieldIndices['certAgency'] ?? 0) + 1,
                  _mergeCtrl!.certAgencyCandidates.length,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),

            // Notes section header
            Text(
              context.l10n.buddies_section_notes,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Notes field
            TextFormField(
              controller: _notesController,
              decoration: _withMergeTextDecoration(
                key: 'notes',
                decoration: InputDecoration(
                  labelText: context.l10n.buddies_field_notes,
                  prefixIcon: const Icon(Icons.notes),
                  hintText: context.l10n.buddies_field_notesHint,
                  alignLabelWithHint: true,
                ),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.isMerging
                          ? context.l10n.buddies_edit_merge_title
                          : isEditing
                          ? context.l10n.buddies_action_update
                          : context.l10n.buddies_action_add,
                    ),
            ),

            // Cancel button
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _confirmCancel(),
              child: Text(context.l10n.common_action_cancel),
            ),
          ],
        ),
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
                  ? context.l10n.buddies_title_edit
                  : context.l10n.buddies_title_add,
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
              child: Text(context.l10n.common_action_cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saveBuddy,
              child: Text(context.l10n.common_action_save),
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
        title: Text(context.l10n.buddies_dialog_discardTitle),
        content: Text(context.l10n.buddies_dialog_discardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.buddies_dialog_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.buddies_dialog_discard),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmMerge() async {
    final count = widget.mergeBuddies?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.buddies_edit_merge_confirmTitle),
        content: Text(context.l10n.buddies_edit_merge_confirmBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.buddies_edit_merge_title),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _saveBuddy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get the current diver ID - preserve existing for edits, get fresh for new buddies
      final diverId =
          _originalBuddy?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final now = DateTime.now();
      final buddy = Buddy(
        id: widget.buddyId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        certificationLevel: _certLevel,
        certificationAgency: _certAgency,
        photoPath: widget.isMerging
            ? _mergeCtrl?.mergedPhotoPath
            : _originalBuddy?.photoPath,
        notes: _notesController.text.trim(),
        createdAt: _originalBuddy?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.isMerging) {
        final confirmed = await _confirmMerge();
        if (!confirmed) {
          setState(() => _isSaving = false);
          return;
        }

        final buddyIds = widget.mergeBuddies!
            .map((b) => b.id)
            .toList(growable: false);
        final mergeSnapshot = await ref
            .read(buddyListNotifierProvider.notifier)
            .mergeBuddies(buddy, buddyIds);
        final savedId = buddyIds.first;

        if (mounted) {
          context.pop(
            BuddyMergeResult(survivorId: savedId, snapshot: mergeSnapshot),
          );
        }
        return;
      }

      Buddy savedBuddy;
      if (isEditing) {
        await ref.read(buddyListNotifierProvider.notifier).updateBuddy(buddy);
        savedBuddy = buddy;
      } else {
        savedBuddy = await ref
            .read(buddyListNotifierProvider.notifier)
            .addBuddy(buddy);
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedBuddy.id);
        } else {
          context.pop(savedBuddy);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? context.l10n.buddies_message_updated
                  : context.l10n.buddies_message_added,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.buddies_message_errorSaving(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
