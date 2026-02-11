import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

class CertificationEditPage extends ConsumerStatefulWidget {
  final String? certificationId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  const CertificationEditPage({
    super.key,
    this.certificationId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

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
  Uint8List? _photoFront;
  Uint8List? _photoBack;

  final _imagePicker = ImagePicker();

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
          _photoFront = cert.photoFront;
          _photoBack = cert.photoBack;
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
              context.l10n.certifications_edit_snackBar_errorLoading(
                e.toString(),
              ),
            ),
          ),
        );
      }
    }
  }

  /// Pick a photo from gallery or camera and return as bytes
  Future<Uint8List?> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(context.l10n.certifications_edit_photo_takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                context.l10n.certifications_edit_photo_chooseFromGallery,
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (picked == null) return null;

      // Read the file bytes directly
      final file = File(picked.path);
      return await file.readAsBytes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.certifications_edit_snackBar_errorPhoto(
                e.toString(),
              ),
            ),
          ),
        );
      }
      return null;
    }
  }

  /// Build a photo card for front or back of certification card
  Widget _buildPhotoCard(
    BuildContext context, {
    required String label,
    required Uint8List? imageData,
    required VoidCallback onPick,
    required VoidCallback onDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPhoto = imageData != null;

    return Semantics(
      button: true,
      label: hasPhoto
          ? context.l10n.certifications_edit_photo_attachedSemanticLabel(label)
          : context.l10n.certifications_edit_photo_addSemanticLabel(label),
      child: AspectRatio(
        aspectRatio: 1.6, // Standard card aspect ratio
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPick,
            child: hasPhoto
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        imageData,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildEmptyPhotoCard(
                            context,
                            label,
                            colorScheme,
                          );
                        },
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: context.l10n
                              .certifications_edit_photo_removeTooltip(label),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          iconSize: 18,
                          onPressed: onDelete,
                        ),
                      ),
                    ],
                  )
                : _buildEmptyPhotoCard(context, label, colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPhotoCard(
    BuildContext context,
    String label,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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
    final body = _isLoading
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
                    decoration: InputDecoration(
                      labelText: context
                          .l10n
                          .certifications_edit_label_certificationName,
                      prefixIcon: const Icon(Icons.card_membership),
                      hintText: context
                          .l10n
                          .certifications_edit_hint_certificationName,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context
                            .l10n
                            .certifications_edit_validation_nameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Agency dropdown
                  DropdownButtonFormField<CertificationAgency>(
                    initialValue: _agency,
                    decoration: InputDecoration(
                      labelText: context.l10n.certifications_edit_label_agency,
                      prefixIcon: const Icon(Icons.business),
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
                    decoration: InputDecoration(
                      labelText: context.l10n.certifications_edit_label_level,
                      prefixIcon: const Icon(Icons.stairs),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          context.l10n.certifications_edit_level_notSpecified,
                        ),
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
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.certifications_edit_label_cardNumber,
                      prefixIcon: const Icon(Icons.numbers),
                      hintText:
                          context.l10n.certifications_edit_hint_cardNumber,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dates section header
                  Text(
                    context.l10n.certifications_edit_sectionTitle_dates,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Issue date picker
                  _DatePickerField(
                    label: context.l10n.certifications_edit_label_issueDate,
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
                    label: context.l10n.certifications_edit_label_expiryDate,
                    value: _expiryDate,
                    icon: Icons.event_busy,
                    helpText: context.l10n.certifications_edit_help_expiryDate,
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
                    context
                        .l10n
                        .certifications_edit_sectionTitle_instructorInfo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Instructor name field
                  TextFormField(
                    controller: _instructorNameController,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.certifications_edit_label_instructorName,
                      prefixIcon: const Icon(Icons.person),
                      hintText:
                          context.l10n.certifications_edit_hint_instructorName,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Instructor number field
                  TextFormField(
                    controller: _instructorNumberController,
                    decoration: InputDecoration(
                      labelText: context
                          .l10n
                          .certifications_edit_label_instructorNumber,
                      prefixIcon: const Icon(Icons.badge),
                      hintText: context
                          .l10n
                          .certifications_edit_hint_instructorNumber,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card photos section
                  Text(
                    context.l10n.certifications_edit_sectionTitle_cardPhotos,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPhotoCard(
                          context,
                          label: context
                              .l10n
                              .certifications_detail_photoLabel_front,
                          imageData: _photoFront,
                          onPick: () async {
                            final bytes = await _pickPhoto();
                            if (bytes != null) {
                              setState(() {
                                _photoFront = bytes;
                                _hasChanges = true;
                              });
                            }
                          },
                          onDelete: () {
                            setState(() {
                              _photoFront = null;
                              _hasChanges = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPhotoCard(
                          context,
                          label: context
                              .l10n
                              .certifications_detail_photoLabel_back,
                          imageData: _photoBack,
                          onPick: () async {
                            final bytes = await _pickPhoto();
                            if (bytes != null) {
                              setState(() {
                                _photoBack = bytes;
                                _hasChanges = true;
                              });
                            }
                          },
                          onDelete: () {
                            setState(() {
                              _photoBack = null;
                              _hasChanges = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Notes section header
                  Text(
                    context.l10n.certifications_edit_sectionTitle_notes,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes field
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: context.l10n.certifications_edit_label_notes,
                      prefixIcon: const Icon(Icons.notes),
                      hintText: context.l10n.certifications_edit_hint_notes,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing
                                ? context.l10n.certifications_edit_button_update
                                : context.l10n.certifications_edit_button_add,
                          ),
                  ),

                  // Cancel button
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _confirmCancel(),
                    child: Text(context.l10n.certifications_edit_button_cancel),
                  ),
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
        if (didPop) return;
        final shouldPop = await _showDiscardDialog();
        if (shouldPop == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing
                ? context.l10n.certifications_edit_appBar_edit
                : context.l10n.certifications_edit_appBar_add,
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
                onPressed: _saveCertification,
                child: Text(context.l10n.certifications_edit_button_save),
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
            isEditing ? Icons.edit : Icons.add_card,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? context.l10n.certifications_edit_appBar_edit
                  : context.l10n.certifications_edit_appBar_add,
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
              child: Text(context.l10n.certifications_edit_button_cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saveCertification,
              child: Text(context.l10n.certifications_edit_button_save),
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
        title: Text(context.l10n.certifications_edit_dialog_discardTitle),
        content: Text(context.l10n.certifications_edit_dialog_discardContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.certifications_edit_dialog_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.certifications_edit_dialog_discard),
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
      final diverId =
          _originalCertification?.diverId ??
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
        photoFront: _photoFront,
        photoBack: _photoBack,
        notes: _notesController.text.trim(),
        createdAt: _originalCertification?.createdAt ?? now,
        updatedAt: now,
      );

      String savedId;
      if (isEditing) {
        await ref
            .read(certificationListNotifierProvider.notifier)
            .updateCertification(cert);
        savedId = cert.id;
      } else {
        final newCert = await ref
            .read(certificationListNotifierProvider.notifier)
            .addCertification(cert);
        savedId = newCert.id;
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
                  ? context.l10n.certifications_edit_snackBar_updated
                  : context.l10n.certifications_edit_snackBar_added,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.certifications_edit_snackBar_errorSaving(
                e.toString(),
              ),
            ),
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
        Semantics(
          button: true,
          label: value != null
              ? '$label: ${DateFormat.yMMMd().format(value!)}. Tap to change'
              : '$label: not set. Tap to select',
          child: InkWell(
            onTap: () => _pickDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                suffixIcon: value != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: context.l10n
                            .certifications_edit_datePicker_clearTooltip(label),
                        onPressed: () => onChanged(null),
                      )
                    : const Icon(Icons.calendar_today),
              ),
              child: Text(
                value != null
                    ? DateFormat.yMMMd().format(value!)
                    : context.l10n.certifications_edit_datePicker_tapToSelect,
                style: TextStyle(
                  color: value != null
                      ? null
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, top: 4),
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
