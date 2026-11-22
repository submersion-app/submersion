import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

final _log = LoggerService.forClass(RecordEditorHost);

/// The one card id an editor's sitting uses. Its History entry names no
/// card, so it reads "Edited" (or "Added" for a create).
const recordEditorCardId = 'editor';

/// Editing for an editor with no read page (issue #4527, phase 4): a
/// preset, a template, a rule, the diver's own profile. A row in a list
/// opens the editor directly, so there is nothing to unlock: the editor
/// opens already in a sitting, on the same tinted Cancel and Save bar as an
/// unlocked record page, and asks before its changes are left behind.
///
/// The editor keeps its own form, controllers and parsing. What it hands
/// the sitting is a **draft** of type [D]: the form's fields as they read
/// on screen ([readEditorDraft]), compared by value. A change typed back is
/// no change, and a value converted for display (psi, cubic feet) never
/// reads as one, since the draft holds the text the diver sees.
///
/// The editor calls [openEditor] once its form is filled, [editorChanged]
/// on every change to the form, builds its page with [editorScaffold], and
/// calls [disposeEditor] from `dispose`. Save runs [writeEditor] in one
/// database transaction and one History entry, then leaves; Cancel and
/// Back ask first when something changed, then leave. A sitting that ends
/// any other way (the app's leave check on a tab switch or a quit, a change
/// of the active diver) leaves too.
mixin RecordEditorHost<W extends ConsumerStatefulWidget, D>
    on ConsumerState<W> {
  // What the editor supplies.

  /// The change log table its record is in, such as `'tank_presets'`.
  String get editorTable;

  /// The id of the record being edited, or null for a new one.
  String? get editorStoredId;

  /// The bar's title.
  String editorTitle(BuildContext context);

  /// The form as it reads now.
  D readEditorDraft();

  /// The form's own checks, run as Save is asked, before anything is
  /// written. False writes nothing and leaves the page as it is, showing
  /// whatever the check showed.
  bool validateEditor();

  /// Writes the record [recordId], inside the sitting's transaction and
  /// change log operation. Throws when nothing could be written: the whole
  /// Save then fails, and the page stays with every value.
  Future<void> writeEditor(String recordId);

  /// What follows a committed Save before the page leaves: lists read
  /// again, a snackbar on [messenger]. The record is saved by then, so a
  /// throw here is logged and the page leaves all the same.
  void afterEditorSaved(ScaffoldMessengerState messenger) {}

  /// Where the page goes once done when there is no page under it to go
  /// back to (the editor's list); null stays. Every editor is opened over
  /// its list, so this is only a fallback.
  String? get editorLeaveLocation => null;

  // What the host provides.

  /// The active diver as Save resolved it, before its transaction opened:
  /// the diver a new record is created under. Read it in [writeEditor];
  /// null before a Save, or when no diver is set up.
  String? get editorDiverId => _saveDiverId;
  String? _saveDiverId;

  /// The id a new record is created with, made once for the page.
  late final String newEditorRecordId = const Uuid().v4();

  /// The record the sitting writes.
  String get editorRecordId => editorStoredId ?? newEditorRecordId;

  /// Whether the editor creates its record.
  bool get editorCreating => editorStoredId == null;

  /// The draft, held whole under the one card the sitting has.
  late final EditField<D, D> _draftField = EditField<D, D>(
    id: 'draft',
    cardId: recordEditorCardId,
    read: (draft) => draft,
    write: (_, draft) => draft,
  );

  RecordEditController<D>? _controller;
  RecordSittingExitBlocker<D>? _exitBlocker;
  RecordEditShortcutTarget? _shortcutTarget;
  RecordEditShortcutTargets? _shortcutTargets;

  /// [openEditor] has run: the page has a sitting, or had one.
  bool _opened = false;

  /// A Save is being written: the sitting ending meanwhile is the save's.
  bool _saving = false;

  /// The page is leaving: nothing leaves again.
  bool _leaving = false;

  /// The active diver the editor is for, noted as the page starts: another
  /// one closes it. Null until a diver is known; the first one known is
  /// adopted, not a switch (the app resolving its default diver).
  String? _diverAtOpen;

  /// The sitting's controller, created on first use.
  RecordEditController<D> get editorController =>
      _controller ??= _newController();

  /// Whether the sitting is open.
  bool get editorOpen => _opened && (_controller?.isUnlocked ?? false);

  /// The draft the sitting opened on: the form as it was filled. An editor
  /// writes what differs from it; null before [openEditor].
  D? get editorStartDraft => _controller?.session?.stored;

  RecordEditController<D> _newController() {
    final container = ProviderScope.containerOf(context, listen: false);
    final controller = RecordEditController<D>(
      creating: editorCreating,
      onSave: (_) => runRecordSitting<void>(
        table: editorTable,
        recordId: editorRecordId,
        changedCardIds: const [],
        body: () => writeEditor(editorRecordId),
      ),
    )..addListener(_onControllerChanged);
    _exitBlocker = RecordSittingExitBlocker<D>(
      controller: controller,
      guard: container.read(appExitGuardProvider),
      confirm: () async {
        if (!mounted) return false;
        return cancelSitting(context, controller);
      },
      // The route the page is on, so leaving another page asks nothing.
      page: () => mounted ? recordSittingPageOf(context) : null,
    );
    return controller;
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _diverAtOpen = ref.read(currentDiverIdProvider);
    final controller = editorController;
    final target = _shortcutTarget = RecordEditShortcutTarget(
      controller: controller,
      // The editor opens in its sitting: there is nothing to unlock.
      unlock: () {},
      save: saveEditor,
      cancel: cancelEditor,
      isCurrent: () =>
          mounted && editorOpen && (ModalRoute.of(context)?.isCurrent ?? true),
    );
    final RecordEditShortcutTargets targets = ref.read(
      recordEditShortcutTargetsProvider,
    );
    _shortcutTargets = targets;
    targets.add(target);
  }

  /// Starts the sitting on the form as it reads now. Call once the form is
  /// filled: after the record has loaded, or at once for a new record.
  void openEditor() {
    if (_opened || _leaving || !mounted) return;
    _opened = true;
    // Another diver became active while the record loaded: it is not the
    // new diver's to edit. The page leaves without a sitting.
    if (_switchedAway(ref.read(currentDiverIdProvider))) {
      setState(() {});
      return;
    }
    editorController.unlock(readEditorDraft());
  }

  /// Hands the form as it reads now to the sitting. Call on every change
  /// to the form; before [openEditor] it does nothing.
  void editorChanged() {
    final session = _controller?.session;
    if (session == null) return;
    session.set<D>(_draftField, readEditorDraft());
  }

  /// Save: the form's checks, then one transaction, then the page leaves.
  /// A save that fails says so, and the page stays with every value.
  Future<void> saveEditor() async {
    if (_saving || _leaving || !editorOpen) return;
    final controller = editorController;
    if (!controller.isDirty || controller.isBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    _saving = true;
    var saved = false;
    try {
      // Resolved before the transaction opens: a provider rebuilding inside
      // it would wait on the transaction's lock, and the transaction on it.
      _saveDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (!mounted) return;
      if (_switchedAway(ref.read(currentDiverIdProvider))) {
        // Another diver became active meanwhile: the record is not theirs.
        _controller?.lock();
      } else if (editorOpen && controller.isDirty && validateEditor()) {
        // Checked now, after the wait, so what is checked is what is
        // written: the form could change while the diver was resolved.
        saved = await controller.save();
      }
    } finally {
      _saving = false;
    }
    if (!mounted) return;
    if (saved) {
      _leaving = true;
      try {
        afterEditorSaved(messenger);
      } catch (error, stackTrace) {
        _log.error(
          'What follows saving $editorTable $editorRecordId failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      _pop();
      return;
    }
    // The diver changed while the save ran (the change was not acted on
    // then): the sitting ends.
    if (_switchedAway(ref.read(currentDiverIdProvider))) _controller?.lock();
    // The sitting ended while Save waited (the app's leave check discarded
    // it, or the diver changed): nothing will tell the page again, so it
    // leaves now.
    if (!editorOpen) {
      _leaveIfEnded(context);
      return;
    }
    final error = controller.saveError;
    if (error == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error is RecordSittingRefusal
              ? error.message(l10n)
              : l10n.recordEdit_saveFailed,
        ),
      ),
    );
  }

  /// Cancel, from the bar or Escape: asks when something changed, then
  /// leaves.
  Future<void> cancelEditor() async {
    if (_leaving || !editorOpen) return;
    if (!await cancelSitting(context, editorController)) return;
    if (!mounted || _leaving) return;
    _leaving = true;
    _pop();
  }

  /// Whether [diverId], the active diver now, is another diver than the
  /// editor's. With none noted yet, [diverId] becomes the editor's: the app
  /// resolving its default diver is not a switch.
  bool _switchedAway(String? diverId) {
    if (_diverAtOpen == null) {
      _diverAtOpen = diverId;
      return false;
    }
    return diverId != _diverAtOpen;
  }

  /// Leaves the page: back to the page under it, or, with none (never the
  /// case in the app, where every editor is opened over its list), to
  /// [editorLeaveLocation] when there is one.
  void _pop() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final location = editorLeaveLocation;
    if (location != null) GoRouter.maybeOf(context)?.go(location);
  }

  /// A sitting that ended without this page's Save or Cancel (the app's
  /// leave check, a change of diver) leaves once the page is the current
  /// route of its navigator: a dialog in the root navigator does not stop
  /// it. Back ends it too, but Back pops the page itself: by the time this
  /// runs the page is no longer current, and nothing is popped twice.
  void _leaveIfEnded(BuildContext context) {
    if (!_opened || _leaving || _saving || editorOpen) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving || _saving || editorOpen) return;
      if (!(ModalRoute.of(this.context)?.isCurrent ?? true)) return;
      _leaving = true;
      _pop();
    });
  }

  /// The page: before the sitting opens (a record loading, or not found) a
  /// plain bar over [body]; then the tinted Cancel and Save bar, with the
  /// leave check around it.
  Widget editorScaffold(BuildContext context, {required Widget body}) {
    // Another diver made active closes the editor, changed or not: its
    // record, or the record it would create, is the other diver's. With
    // changes, the switch has already asked through the app's leave check.
    ref.listen<String?>(currentDiverIdProvider, (_, next) {
      if (_leaving || _saving) return;
      // Before the sitting opens, openEditor checks the diver itself.
      if (_switchedAway(next) && _opened) _controller?.lock();
    });
    if (!_opened) {
      return Scaffold(
        appBar: AppBar(title: Text(editorTitle(context))),
        body: body,
      );
    }
    _leaveIfEnded(context);
    final controller = editorController;
    return RecordEditLeaveGuard<D>(
      controller: controller,
      child: Scaffold(
        appBar: RecordEditBar(
          title: editorTitle(context),
          canSave: controller.isDirty,
          isSaving: controller.isSaving,
          isBusy: controller.isOperating,
          onCancel: cancelEditor,
          onSave: saveEditor,
        ),
        body: RecordEditScope<D>(controller: controller, child: body),
      ),
    );
  }

  /// Ends the editor's sitting and lets go of what it holds. Call from the
  /// page's `dispose`.
  void disposeEditor() {
    final target = _shortcutTarget;
    if (target != null) _shortcutTargets?.remove(target);
    _exitBlocker?.dispose();
    _controller
      ?..removeListener(_onControllerChanged)
      ..dispose();
  }
}
