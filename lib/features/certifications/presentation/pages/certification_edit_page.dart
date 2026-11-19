import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/presentation/widgets/instructor_picker_field.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_form_widgets.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_agency_dropdown.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_level_dialog.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

class CertificationEditPage extends ConsumerStatefulWidget {
  final String? certificationId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  /// Staging mode (issue #553): when [onStaged] is provided, Save builds the
  /// [Certification] and hands it back via the callback WITHOUT persisting (no
  /// diver-id lookup, no repository write). [initialCertification] prefills the
  /// form from an in-memory staged cert instead of loading by id. Used by the
  /// buddy edit form to stage a buddy's certs and commit them on its own Save.
  final Certification? initialCertification;
  final void Function(Certification result)? onStaged;

  /// Test seam: replaces the platform image picker, which has no Dart-side
  /// entry point a fake can be injected through. Receives the source and
  /// returns the raw bytes plus a declared name, or null when the user
  /// cancels. Mirrors [OcrScanPage.pickImageOverride].
  final Future<({Uint8List bytes, String name})?> Function(ImageSource source)?
  pickPhotoOverride;

  const CertificationEditPage({
    super.key,
    this.certificationId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.initialCertification,
    this.onStaged,
    @visibleForTesting this.pickPhotoOverride,
  }) : assert(
         onStaged == null || certificationId == null,
         'Staging mode (onStaged) prefills from initialCertification and never '
         'loads by id -- do not also pass certificationId.',
       ),
       assert(
         initialCertification == null || onStaged != null,
         'initialCertification is only read in staging mode; pass onStaged too, '
         'or the persistent save path would run on the prefilled data.',
       );

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

  /// Agency and level ids: built-in enum names or custom ids (issue #690).
  String _agency = CertificationAgency.padi.name;
  String? _level;

  /// Recognitions this card grants beyond ([_agency], [_level]). Rendered as
  /// equal rows in the credential list -- ([_agency], [_level]) is just row 0,
  /// not a primary. Saved to Certification.additionalCredentials.
  final List<_Cred> _extraCredentials = [];

  DateTime? _issueDate;
  DateTime? _expiryDate;
  Uint8List? _photoFront;
  Uint8List? _photoBack;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  Certification? _originalCertification;
  String? _instructorId;

  // Editing when opened by id (self-diver flow) OR when staging an existing
  // cert (non-empty initialCertification.id) -- otherwise the "Add" labels
  // show while editing a staged buddy cert (issue #553 review).
  bool get isEditing =>
      widget.certificationId != null ||
      (widget.initialCertification?.id.isNotEmpty ?? false);
  bool get _isStaging => widget.onStaged != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialCertification != null) {
      _prefillFrom(widget.initialCertification!);
    } else if (isEditing) {
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

  /// Prefill the form from an in-memory (possibly unpersisted) certification,
  /// used by staging mode instead of loading by id.
  void _prefillFrom(Certification cert) {
    _originalCertification = cert;
    // A name that merely repeats agency + level is shown as blank, so the
    // field's hint offers the derivation instead of duplicating it.
    _nameController.text = hasDerivedName(cert, catalog: _catalog)
        ? ''
        : cert.name;
    _cardNumberController.text = cert.cardNumber ?? '';
    _instructorNameController.text = cert.instructorName ?? '';
    _instructorNumberController.text = cert.instructorNumber ?? '';
    _notesController.text = cert.notes;
    _agency = cert.agency;
    _level = cert.level;
    _extraCredentials
      ..clear()
      ..addAll(cert.additionalCredentials.map((c) => _Cred(c.agency, c.level)));

    _issueDate = cert.issueDate;
    _expiryDate = cert.expiryDate;
    _photoFront = cert.photoFront;
    _photoBack = cert.photoBack;
    _instructorId = cert.instructorId;
  }

  Future<void> _loadCertification() async {
    setState(() => _isLoading = true);
    try {
      final cert = await ref
          .read(certificationRepositoryProvider)
          .getCertificationById(widget.certificationId!);
      if (cert != null && mounted) {
        _originalCertification = cert;
        // See _prefillFrom: a derived name renders as a blank field.
        _nameController.text = hasDerivedName(cert, catalog: _catalog)
            ? ''
            : cert.name;
        _cardNumberController.text = cert.cardNumber ?? '';
        _instructorNameController.text = cert.instructorName ?? '';
        _instructorNumberController.text = cert.instructorNumber ?? '';
        _notesController.text = cert.notes;
        setState(() {
          _agency = cert.agency;
          _level = cert.level;
          _extraCredentials
            ..clear()
            ..addAll(
              cert.additionalCredentials.map((c) => _Cred(c.agency, c.level)),
            );
          _issueDate = cert.issueDate;
          _expiryDate = cert.expiryDate;
          _photoFront = cert.photoFront;
          _photoBack = cert.photoBack;
          _instructorId = cert.instructorId;
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
  Future<Uint8List?> _pickPhoto() => pickCertificationCardPhoto(
    context,
    pickOverride: widget.pickPhotoOverride,
  );

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _cardNumberController.dispose();
    _instructorNameController.dispose();
    _instructorNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Built-in and custom agencies and levels (issue #690).
  CertificationCatalog get _catalog => context.certificationCatalog;

  /// Bumped to remount a level field after the add action, so the action
  /// row is never left showing as the selection when the dialog is
  /// cancelled.
  int _levelRevision = 0;

  String _agencyAt(int i) => i == 0 ? _agency : _extraCredentials[i - 1].agency;
  String? _levelAt(int i) => i == 0 ? _level : _extraCredentials[i - 1].level;

  void _setAgencyAt(int i, String agency) {
    setState(() {
      // A level from another agency's catalog is reset -- a visible
      // consequence of the user's own switch.
      final level = _levelAt(i);
      // A custom agency has no built-in rungs. Checked by id as well as by
      // catalog, because one just created from the dropdown is not in the
      // catalog until it reloads (issue #690).
      final customAgency = CertificationAgency.fromId(agency) == null;
      final resetLevel =
          level != null &&
          ((customAgency && CertificationLevel.fromId(level) != null) ||
              !_catalog.levelsFor(agency).any((e) => e.id == level));
      if (i == 0) {
        _agency = agency;
        if (resetLevel) _level = null;
      } else {
        _extraCredentials[i - 1].agency = agency;
        if (resetLevel) _extraCredentials[i - 1].level = null;
      }
      _hasChanges = true;
    });
  }

  /// The add action opens the certification dialog for [agency] and selects
  /// what it creates; any other option is an ordinary selection.
  Future<void> _onLevelChanged(
    int i,
    String agency,
    CertificationOption? option,
  ) async {
    if (option == null || !option.isAddCustom) {
      _setLevelAt(i, option?.level);
      return;
    }
    final created = await showCertificationLevelDialog(
      context,
      agencyId: agency,
    );
    if (!mounted) return;
    setState(() => _levelRevision++);
    if (created != null) _setLevelAt(i, created.id);
  }

  void _setLevelAt(int i, String? level) {
    setState(() {
      if (i == 0) {
        _level = level;
      } else {
        _extraCredentials[i - 1].level = level;
      }
      _hasChanges = true;
    });
  }

  void _removeCredentialAt(int i) {
    setState(() {
      if (i == 0) {
        // Promote the next recognition into row 0 so the card keeps one.
        final next = _extraCredentials.removeAt(0);
        _agency = next.agency;
        _level = next.level;
      } else {
        _extraCredentials.removeAt(i - 1);
      }
      _hasChanges = true;
    });
  }

  /// One (agency, level) row. Every row is equal; the trailing remove button
  /// is shown only when the card has more than one recognition.
  Widget _credentialRow(BuildContext context, int i) {
    final agency = _agencyAt(i);
    final level = _levelAt(i);
    final canRemove = _extraCredentials.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CertificationAgencyDropdown(
                key: ValueKey('cred-agency-$i'),
                value: agency,
                labelText: context.l10n.certifications_edit_label_agency,
                isDense: true,
                onChanged: (value) => _setAgencyAt(i, value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CertificationOption>(
                // The key forces a remount when the agency changes or the
                // level is reset externally, so initialValue is re-read.
                key: ValueKey('cred-level-$i-$agency-$level-$_levelRevision'),
                initialValue: CertificationOption.value(level),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      context.l10n.certifications_edit_label_certification,
                  prefixIcon: const Icon(Icons.workspace_premium),
                  isDense: true,
                ),
                items: certificationLevelItems(
                  context,
                  _catalog,
                  agency,
                  level,
                ),
                onChanged: (option) => _onLevelChanged(i, agency, option),
              ),
            ],
          ),
        ),
        if (canRemove)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.certifications_edit_removeRecognition,
            onPressed: () => _removeCredentialAt(i),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Credential list: each row is an equal (agency, level)
                  // recognition the card grants. Row 0 is stored in
                  // _agency/_level, the rest in _extraCredentials -- no primary.
                  for (var i = 0; i < 1 + _extraCredentials.length; i++) ...[
                    _credentialRow(context, i),
                    const SizedBox(height: 16),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _extraCredentials.add(_Cred(_agency, null));
                        _hasChanges = true;
                      }),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.l10n.certifications_edit_addRecognition,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Certification title: optional. Blank means "use the
                  // derived title", which the hint shows live. A value here
                  // replaces the certification as the card's title on every
                  // surface, so the label must not read as the diver's name.
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.certifications_edit_label_title,
                      prefixIcon: const Icon(Icons.card_membership),
                      hintText: derivedCertificationTitleL10n(
                        _agency,
                        _level,
                        context.l10n,
                        catalog: context.certificationCatalog,
                      ),
                      helperText: context.l10n.certifications_edit_helper_title,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if ((value == null || value.trim().isEmpty) &&
                          _level == null) {
                        return context
                            .l10n
                            .certifications_edit_validation_certificationOrTitleRequired;
                      }
                      return null;
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
                  CertificationDatePickerField(
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
                  CertificationDatePickerField(
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

                  InstructorPickerField(
                    instructorId: _instructorId,
                    onSelected: (buddy, instructorCert) {
                      setState(() {
                        _instructorId = buddy?.id;
                        _hasChanges = true;
                        if (buddy != null) {
                          // Snapshot the picked buddy fully: overwrite both
                          // name and number so switching to a buddy without a
                          // card number clears a stale one rather than
                          // leaving the previous selection's value behind.
                          _instructorNameController.text = buddy.name;
                          _instructorNumberController.text =
                              instructorCert?.cardNumber ?? '';
                        }
                        // Clearing to None keeps the text fields untouched.
                      });
                    },
                  ),
                  const SizedBox(height: 16),

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
                        child: CertificationPhotoCard(
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
                        child: CertificationPhotoCard(
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
                  MarkdownNotesField(
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
        // In a Training tab the diver has switched away from, Back leaves
        // rather than asking about a form that is not on screen (#3437).
        canPop: !_hasChanges || !TabVisibility.isVisible(context),
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
            AppBarTextAction(
              label: context.l10n.certifications_edit_button_save,
              onPressed: _isSaving ? null : _saveCertification,
              busy: _isSaving,
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
      child: LabelWithControl(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEditing ? Icons.edit : Icons.add_card,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                isEditing
                    ? context.l10n.certifications_edit_appBar_edit
                    : context.l10n.certifications_edit_appBar_add,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        control: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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

    // issue #553 staging mode: build the cert and hand it back via onStaged;
    // do NOT persist (the buddy edit form commits it on its own Save). Handled
    // before the saving spinner because staging is synchronous -- setting
    // _isSaving and returning would leave an embedded editor spinning forever
    // if its host keeps it mounted.
    if (_isStaging) {
      final now = DateTime.now();
      final result = Certification(
        id: widget.initialCertification?.id ?? '',
        diverId: widget.initialCertification?.diverId,
        buddyId: widget.initialCertification?.buddyId,
        name: _nameController.text.trim(),
        agency: _agency,
        level: _level,
        additionalCredentials: _extraCredentials
            .map(
              (c) => CertificationCredential(agency: c.agency, level: c.level),
            )
            .toList(),
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
        instructorId: _instructorId,
        photoFront: _photoFront,
        photoBack: _photoBack,
        notes: _notesController.text.trim(),
        createdAt: widget.initialCertification?.createdAt ?? now,
        // Preserve updatedAt so an unmodified Save equals the persisted cert
        // and replaceBuddyCertifications skips it (issue #553 review). A real
        // edit changes another prop, so the update still fires -- and
        // updateCertification stamps its own updatedAt on commit anyway.
        updatedAt: widget.initialCertification?.updatedAt ?? now,
      );
      widget.onStaged!(result);
      if (widget.embedded) {
        widget.onSaved?.call(result.id);
      } else {
        context.pop();
      }
      return;
    }

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
        additionalCredentials: _extraCredentials
            .map(
              (c) => CertificationCredential(agency: c.agency, level: c.level),
            )
            .toList(),
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
        instructorId: _instructorId,
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

/// A mutable (agency, level) pair while the credential list is being edited.
class _Cred {
  String agency;
  String? level;
  _Cred(this.agency, this.level);
}
