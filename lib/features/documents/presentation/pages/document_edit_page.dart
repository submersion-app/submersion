import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_form_fields.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_field.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_picker_sheet.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/byte_format.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Creates or edits one document and its pages (issue #2613).
class DocumentEditPage extends ConsumerStatefulWidget {
  /// Null creates a new document.
  final String? documentId;

  /// Where a new document starts filed; the form can change it. Ignored
  /// when editing, which starts at the document's own owner.
  final DocumentOwner owner;
  final DocumentType? initialType;
  final bool embedded;

  /// Called with the saved document's id; null pops the route instead.
  final ValueChanged<String>? onSaved;
  final VoidCallback? onCancel;

  /// Test seam for the platform pickers.
  final DocumentPageCapture? capture;

  /// Test seam for the owner picker sheet.
  final Future<DocumentOwner?> Function(BuildContext, DocumentOwner)? pickOwner;

  const DocumentEditPage({
    super.key,
    this.documentId,
    this.owner = const DocumentOwner.personal(),
    this.initialType,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    @visibleForTesting this.capture,
    @visibleForTesting this.pickOwner,
  });

  @override
  ConsumerState<DocumentEditPage> createState() => _DocumentEditPageState();
}

class _DocumentEditPageState extends ConsumerState<DocumentEditPage> {
  final _controllers = DocumentFormControllers();
  late final DocumentPageCapture _capture =
      widget.capture ?? DocumentPageCapture();

  Document? _original;
  late DocumentOwner _owner = widget.owner;
  late DocumentType _type = widget.initialType ?? DocumentType.other;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  int _lead = Document.defaultReminderLeadDays;
  bool _isPrimary = false;
  List<DocumentPage> _pages = const [];
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  bool get _isNew => widget.documentId == null;

  @override
  void initState() {
    super.initState();
    for (final c in _controllers.all) {
      c.addListener(_markChanged);
    }
    _load();
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges && !_loading) setState(() => _hasChanges = true);
  }

  Future<void> _load() async {
    final id = widget.documentId;
    if (id == null) {
      // A diver's first insurance is the one the emergency card and the
      // home chip use; a later one leaves the existing primary alone.
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId != null) {
        final repo = ref.read(documentRepositoryProvider);
        _isPrimary = !await repo.hasPrimaryInsurance(diverId);
      }
    }
    if (id != null) {
      final repo = ref.read(documentRepositoryProvider);
      final doc = await repo.getById(id);
      final pages = await repo.getPages(id);
      if (!mounted) return;
      if (doc != null) {
        _original = doc;
        _owner = doc.owner;
        _type = doc.type;
        _controllers.title.text = doc.title;
        _controllers.issuer.text = doc.issuer ?? '';
        _controllers.number.text = doc.referenceNumber ?? '';
        _controllers.emergencyPhone.text = doc.emergencyPhone ?? '';
        _controllers.phone.text = doc.phone ?? '';
        _controllers.notes.text = doc.notes;
        _issueDate = doc.issueDate;
        _expiryDate = doc.expiryDate;
        _lead = doc.effectiveReminderLeadDays;
        _isPrimary = doc.isPrimary;
        _pages = pages;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// A card document is made from its certification and stays a card: its
  /// id is derived from the certification, so retyping it would leave a
  /// non-card the certification still treats as its card.
  List<DocumentType> get _typeChoices => _type == DocumentType.certificationCard
      ? const [DocumentType.certificationCard]
      : [
          for (final t in DocumentType.values)
            if (t != DocumentType.certificationCard) t,
        ];

  Future<void> _pickOwner() async {
    final pick =
        widget.pickOwner ??
        (context, current) =>
            showDocumentOwnerPicker(context, current: current);
    final chosen = await pick(context, _owner);
    if (chosen == null || chosen == _owner || !mounted) return;
    _change(() => _owner = chosen);
  }

  void _change(VoidCallback update) => setState(() {
    update();
    _hasChanges = true;
  });

  Future<void> _pickDate({required bool expiry}) async {
    final now = DateTime.now();
    final current = expiry ? _expiryDate : _issueDate;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    _change(() => expiry ? _expiryDate = picked : _issueDate = picked);
  }

  /// Asks where the page comes from, captures it, and puts it in the slot
  /// [side] names (replacing what was there) or at the end.
  Future<void> _addPage(DocumentPageSide? side) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final canUseCamera = Platform.isAndroid || Platform.isIOS;
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUseCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(l10n.documents_pages_addCamera),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.documents_pages_addGallery),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(l10n.documents_pages_addFile),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final PageCaptureResult result;
    try {
      result = switch (source) {
        'camera' => await _capture.fromImage(ImageSource.camera, side: side),
        'gallery' => await _capture.fromImage(ImageSource.gallery, side: side),
        _ => await _capture.fromFile(side: side),
      };
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.media_import_failedToImportError('$e'))),
      );
      return;
    }
    if (!mounted) return;
    final refusal = switch (result) {
      PageCaptureTooLarge(:final sizeBytes) => l10n.documents_pages_tooLarge(
        formatBytes(sizeBytes),
      ),
      PageCaptureUnsupported(:final extension) =>
        l10n.documents_pages_unsupported(extension),
      PageCaptureImageTooLarge() => l10n.profilePhoto_error_tooLarge,
      PageCaptureUndecodable() => l10n.profilePhoto_error_undecodable,
      PageCaptured() || PageCaptureCancelled() => null,
    };
    if (refusal != null) {
      messenger.showSnackBar(SnackBar(content: Text(refusal)));
      return;
    }
    if (result is! PageCaptured) return;
    final captured = result.page;
    _change(() {
      final next = [
        for (final p in _pages)
          if (side == null || p.side != side) p,
        captured,
      ];
      // A card face goes where the strip shows it, Front then Back ahead of
      // the other pages: the stored order is what the viewer pages through.
      _pages = side == null
          ? next
          : [
              for (final s in DocumentPageSide.values)
                ...next.where((p) => p.side == s),
              ...next.where((p) => p.side == null),
            ];
    });
  }

  String? _text(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final diverId =
          _original?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) throw StateError('No active diver');
      final now = DateTime.now();
      final insurance = _type == DocumentType.insurance;
      final card = _type == DocumentType.certificationCard;
      final doc = Document(
        id: _original?.id ?? '',
        diverId: diverId,
        owner: _owner,
        type: _type,
        title: _controllers.title.text.trim(),
        issuer: _text(_controllers.issuer),
        referenceNumber: _text(_controllers.number),
        issueDate: _issueDate,
        expiryDate: card ? null : _expiryDate,
        reminderLeadDays: _lead == Document.defaultReminderLeadDays
            ? null
            : _lead,
        emergencyPhone: insurance ? _text(_controllers.emergencyPhone) : null,
        phone: insurance ? _text(_controllers.phone) : null,
        isPrimary: insurance && _isPrimary,
        notes: _controllers.notes.text.trim(),
        createdAt: _original?.createdAt ?? now,
        updatedAt: now,
      );
      final saved = await ref.read(documentMutationsProvider).save(doc, _pages);
      if (!mounted) return;
      _hasChanges = false;
      messenger.showSnackBar(SnackBar(content: Text(l10n.documents_saved)));
      if (widget.onSaved != null) {
        widget.onSaved!(saved.id);
      } else {
        context.pop();
      }
    } catch (e) {
      // The form keeps everything the diver entered.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.documents_error_save('$e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The pane's close button asks before discarding, as Back does.
  Future<void> _closeEmbedded() async {
    if (_hasChanges && await _confirmDiscard() != true) return;
    if (!mounted) return;
    _hasChanges = false;
    widget.onCancel?.call();
  }

  Future<bool?> _confirmDiscard() => showDialog<bool>(
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final title = Text(
      _isNew ? l10n.documents_edit_newTitle : l10n.documents_edit_editTitle,
    );
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DocumentOwnerField(
                  owner: _owner,
                  locked: _type == DocumentType.certificationCard,
                  onTap: _pickOwner,
                ),
                const SizedBox(height: 16),
                DocumentFormFields(
                  type: _type,
                  typeChoices: _typeChoices,
                  controllers: _controllers,
                  issueDate: _issueDate,
                  expiryDate: _expiryDate,
                  reminderLeadDays: _lead,
                  isPrimary: _isPrimary,
                  formatDate: units.formatDate,
                  onTypeChanged: (t) => _change(() => _type = t),
                  onPickIssueDate: () => _pickDate(expiry: false),
                  onPickExpiryDate: () => _pickDate(expiry: true),
                  onClearIssueDate: () => _change(() => _issueDate = null),
                  onClearExpiryDate: () => _change(() => _expiryDate = null),
                  onLeadChanged: (d) => _change(() => _lead = d),
                  onPrimaryChanged: (v) => _change(() => _isPrimary = v),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.documents_pages_title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DocumentPageStrip(
                  pages: _pages,
                  cardSlots:
                      _type == DocumentType.insurance ||
                      _type == DocumentType.certificationCard,
                  onChanged: (pages) => _change(() => _pages = pages),
                  onAdd: _addPage,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers.notes,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l10n.documents_field_notes,
                  ),
                ),
              ],
            ),
          );
    final saveAction = _saving
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : AppBarTextAction(
            label: l10n.divers_edit_saveButton,
            onPressed: _loading ? null : _save,
          );
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_hasChanges) return;
        final discard = await _confirmDiscard();
        if (discard != true || !context.mounted) return;
        _hasChanges = false;
        if (widget.onCancel != null) {
          widget.onCancel!();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: title,
          automaticallyImplyLeading: !widget.embedded,
          leading: widget.embedded && widget.onCancel != null
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _closeEmbedded,
                )
              : null,
          actions: [saveAction],
        ),
        body: body,
      ),
    );
  }
}
