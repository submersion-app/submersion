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
import 'package:submersion/shared/widgets/record_editing/record_editor_menu.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

export 'package:submersion/shared/widgets/record_editing/record_editor_menu.dart'
    show RecordEditorOperation;

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

  /// Whether the form, as it reads now, may be saved at all: a rule with
  /// no name or no action may not. Save is enabled only while this holds
  /// and something has changed, and Cmd or Ctrl+S does nothing otherwise.
  /// True by default. Read on every build of the bar, so the editor
  /// rebuilds when its answer changes.
  bool get editorCanSave => true;

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

  /// The whole-record operations in the bar's menu (decision 3), such as a
  /// transmitter's Remove key. None by default; a new record never shows
  /// them, as there is nothing stored for them to act on.
  List<RecordEditorOperation> editorOperations(BuildContext context) =>
      const [];

  /// What a committed Save hands back to the page that pushed the editor,
  /// read after [afterEditorSaved]: the Transmitter card offers its Apply
  /// from it. Back, Cancel and every other way of leaving hand back null.
  Object? get editorSavedResult => null;

  /// Told of a Save whose write threw, before anything is shown. True when
  /// the editor has shown the failure in its own form (a duplicate serial
  /// under its field), so no snackbar is needed. The page stays with every
  /// value either way.
  bool editorSaveFailed(Object error) => false;

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

  /// The diver the editor is for: the active diver as the app resolves it
  /// (`validatedCurrentDiverIdProvider`, the id a new record is written
  /// under), noted as the page starts. Another one closes the editor. Null
  /// until a diver is known; the first one known is noted, not a switch.
  /// A repair of the raw id that resolves to the same diver (a deleted
  /// diver's id replaced by the default diver it already resolved to)
  /// changes nothing here.
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
    // `value`, not `valueOrNull`: while the diver is being worked out again
    // (after a divers-table change) it still holds the diver it is
    // replacing, which is the one active as the page starts.
    _noteDiver(ref.read(validatedCurrentDiverIdProvider).value);
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
  ///
  /// With [from], the record before its seed (a new configuration's unit, a
  /// key prefilled with its item's serial), the sitting opens on [from] and
  /// the form as it reads now is its first change, so Save is enabled at
  /// once (pattern: seeds are changes). A [from] equal to the form is no
  /// change.
  void openEditor({D? from}) {
    if (_opened || _leaving || !mounted) return;
    _opened = true;
    // Another diver became active while the record loaded: it is not the
    // new diver's to edit. The page leaves without a sitting.
    // `value` keeps the diver being replaced while it is worked out again;
    // the listener sees the settled answer.
    final diverId = ref.read(validatedCurrentDiverIdProvider).value;
    _noteDiver(diverId);
    if (_isAnotherDiver(diverId)) {
      setState(() {});
      return;
    }
    editorController.unlock(from ?? readEditorDraft());
    if (from != null) editorChanged();
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
    if (!controller.isDirty || controller.isBusy || !editorCanSave) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // The bar shows the save from here: the wait for the diver below is
    // part of it, and Cancel must not discard what is being saved.
    setState(() => _saving = true);
    var saved = false;
    var diverUnknown = false;
    try {
      // Resolved before the transaction opens: a provider rebuilding inside
      // it would wait on the transaction's lock, and the transaction on it.
      String? diverId;
      try {
        diverId = await _resolvedDiver();
      } catch (error, stackTrace) {
        // The diver could not be worked out (a read that failed): nothing
        // is written, and the Save says it failed.
        diverUnknown = true;
        _log.error(
          'Working out the diver to save $editorTable $editorRecordId failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (mounted && !diverUnknown) {
        _saveDiverId = diverId;
        _noteDiver(diverId);
        if (_isAnotherDiver(diverId)) {
          // Another diver became active meanwhile: the record is not theirs.
          _controller?.lock();
        } else if (editorOpen && controller.isDirty && validateEditor()) {
          // Checked now, after any wait, so what is checked is what is
          // written: the form could change while the diver was resolved.
          saved = await controller.save();
        }
      }
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    if (diverUnknown) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordEdit_saveFailed)),
      );
      return;
    }
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
      _pop(editorSavedResult);
      return;
    }
    // The diver changed while the save ran (the change was not acted on
    // then): the sitting ends. One still being worked out reaches the
    // listener once settled, now that the save is over.
    final diverNow = ref.read(validatedCurrentDiverIdProvider);
    if (_isSettled(diverNow) && _isAnotherDiver(diverNow.valueOrNull)) {
      _controller?.lock();
    }
    // The sitting ended while Save waited (the app's leave check discarded
    // it, or the diver changed): nothing will tell the page again, so it
    // leaves now.
    if (!editorOpen) {
      _leaveIfEnded(context);
      return;
    }
    final error = controller.saveError;
    if (error == null) return;
    // The editor shows this one in its own form.
    if (editorSaveFailed(error)) return;
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
  /// leaves. Not while Save is working: what it is saving is not to be
  /// discarded under it.
  Future<void> cancelEditor() async {
    if (_leaving || _saving || !editorOpen) return;
    if (!await cancelSitting(context, editorController)) return;
    if (!mounted || _leaving) return;
    _leaving = true;
    _pop();
  }

  /// The active diver for Save: the one already worked out, at once, or the
  /// one being worked out, once it is. Throws when it cannot be.
  Future<String?> _resolvedDiver() async {
    final known = ref.read(validatedCurrentDiverIdProvider);
    if (_isSettled(known)) return known.valueOrNull;
    return ref.read(validatedCurrentDiverIdProvider.future);
  }

  /// Whether [diver] is a settled answer: worked out, not being worked out
  /// again, and not failed.
  static bool _isSettled(AsyncValue<String?> diver) =>
      diver.hasValue && !diver.isLoading && !diver.hasError;

  /// Notes [diverId] as the editor's diver when none is noted yet: the
  /// first diver known is the editor's, not a switch.
  void _noteDiver(String? diverId) => _diverAtOpen ??= diverId;

  /// Whether [diverId], the active diver now, is another diver than the
  /// editor's. False while the editor has none noted.
  bool _isAnotherDiver(String? diverId) =>
      _diverAtOpen != null && diverId != _diverAtOpen;

  /// Leaves the page, once: for an editor whose record could not be opened
  /// (gone, or failed to load) as for a finished one. A page whose route is
  /// still coming in leaves as soon as it has.
  void leaveEditor() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _pop();
  }

  /// Runs [operation] from the bar's menu through the operation gate, and
  /// leaves once it has written: the record it acted on is gone or changed
  /// under the editor.
  Future<void> _runOperation(RecordEditorOperation operation) async {
    if (_leaving || _saving || !editorOpen) return;
    var wrote = false;
    await recordOperationRunnerOf(
      editorController,
      record: '$editorTable $editorRecordId',
    )(() async => wrote = await operation.run());
    if (wrote) leaveEditor();
  }

  /// Leaves the page: back to the page under it, handing it [result], or,
  /// with none (never the case in the app, where every editor is opened
  /// over its list), to [editorLeaveLocation] when there is one.
  ///
  /// A page whose route is still coming in (a record that turned out to be
  /// missing, found while the page was pushed) leaves once it has: a route
  /// is not popped in the middle of its push.
  void _pop([Object? result]) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      void settled(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(settled);
        // The navigator marks the push done just after its animation ends,
        // within the same frame: the page leaves once the frame is drawn.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pop(result);
        });
      }

      animation.addStatusListener(settled);
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
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
    ref.listen<AsyncValue<String?>>(validatedCurrentDiverIdProvider, (_, next) {
      // Only a settled answer: one being worked out again still carries the
      // diver it is replacing.
      if (!_isSettled(next)) return;
      if (_leaving || _saving) return;
      final diverId = next.valueOrNull;
      _noteDiver(diverId);
      // Before the sitting opens, openEditor checks the diver itself.
      if (_opened && _isAnotherDiver(diverId)) _controller?.lock();
    });
    if (!_opened) {
      return Scaffold(
        appBar: AppBar(title: Text(editorTitle(context))),
        body: body,
      );
    }
    _leaveIfEnded(context);
    final controller = editorController;
    final operations = editorCreating
        ? const <RecordEditorOperation>[]
        : editorOperations(context);
    return RecordEditLeaveGuard<D>(
      controller: controller,
      child: Scaffold(
        appBar: RecordEditBar(
          title: editorTitle(context),
          canSave: controller.isDirty && editorCanSave,
          isSaving: controller.isSaving || _saving,
          isBusy: controller.isOperating,
          onCancel: cancelEditor,
          onSave: saveEditor,
          actions: [
            if (operations.isNotEmpty)
              RecordEditorMenu(
                controller: controller,
                operations: operations,
                onSelected: _runOperation,
              ),
          ],
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
