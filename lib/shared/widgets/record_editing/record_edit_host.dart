import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip_layout.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

/// In-place editing for a record page (issue #4527): what every record page
/// that edits in place needs, whatever its record of type [T].
///
/// The page opens locked. Unlocking starts a sitting: the top bar becomes
/// Cancel and Save, the cards that can be edited gain a pencil, and cards
/// the page leaves out are offered in a strip under the bar. Save writes
/// the whole sitting at once and locks again.
///
/// The record page supplies what is its own (its cards, its save, its
/// strip, its title) through the members it must implement, and builds its
/// page with [editScaffold] on a full page or [editPane] in a list pane.
/// It calls [followStored] from `build` and [disposeEditing] from
/// `dispose`.
mixin RecordEditHost<W extends ConsumerStatefulWidget, T> on ConsumerState<W> {
  // What the record page supplies.

  /// The id of the record the page shows.
  String get hostRecordId;

  /// The id of [record].
  String recordIdOf(T record);

  /// Whether the page is of a record not yet created; while it is, Save and
  /// Cancel are [saveNewRecord] and [cancelNewRecord].
  bool get isCreating => false;

  /// Whether the page offers editing now: it can change while the page
  /// lives (a library role that loads, or is taken away). While it does
  /// not, the page never unlocks and the editing keys pass it by.
  bool get offersEditing => true;

  /// Writes [session], the record's own save. Throws when nothing could be
  /// written. Sets [justSavedRecord] once its write has committed.
  Future<void> saveSitting(EditSession<T> session);

  /// The record as stored now, after a whole-record operation has written
  /// it; null when it no longer exists.
  Future<T?> rereadStored(ProviderContainer container, T stored);

  /// The record's cards that can be edited, in page order: each one's own
  /// check is asked at Save, open or not.
  Iterable<EditCard<T>> get hostEditCards;

  /// Told of each sitting as it starts, before any card opens, whichever
  /// way the page was unlocked. The container, not the page's `ref`: a held
  /// write can run after the page has gone.
  void onSittingStart(EditSession<T> session, ProviderContainer container) {}

  /// The record as stored, which the unlock key starts a sitting from, or
  /// null while it has not been read.
  T? get storedForUnlock;

  /// The unlocked bar's title for [record].
  String editingTitle(T record);

  /// The cards the page is not showing for [working], in the page's order:
  /// hidden by the diver, or with nothing to show.
  List<AddStripEntry> addStripEntries(T working);

  /// What is pinned under the strip while the record is unlocked, if
  /// anything.
  Widget? belowStrip(T shown) => null;

  /// Whether the page is the one the editing keys act on, beyond being
  /// mounted and its route current.
  bool get isShortcutTargetInView => true;

  /// Save and Cancel for a record not yet created ([isCreating]).
  Future<void> saveNewRecord() => throw UnimplementedError();
  Future<void> cancelNewRecord() => throw UnimplementedError();

  /// The sitting of the record's own page, when this page is a satellite of
  /// it (a passport, the cylinder board) pushed during that sitting
  /// (`pushRecordSatellite`); null when the page holds its own.
  ///
  /// While it is given, the page creates no controller or exit blocker: the
  /// record's page owns them and saves or cancels what is changed here. The
  /// page shows Done ([finishJoinedSitting]) in place of Cancel and Save,
  /// and its Save and Cancel keys finish it too; it offers no lock and asks
  /// nothing on leaving.
  RecordEditController<T>? get joinedSitting => null;

  /// [joinedSitting], while it belongs to the record the page shows: the
  /// one the page was showing when handed it, and the one its sitting, if
  /// any, is on. A page handed another record does not edit, or follow, the
  /// one it was opened for.
  RecordEditController<T>? get _joined {
    final joined = joinedSitting;
    if (joined == null) return null;
    final joinedFor = _joinedFor;
    if (identical(joinedFor?.controller, joined) &&
        joinedFor!.recordId != hostRecordId) {
      return null;
    }
    final session = joined.session;
    if (session != null && recordIdOf(session.stored) != hostRecordId) {
      return null;
    }
    return joined;
  }

  /// The joined sitting the page was handed, and the record it was showing
  /// then, which that sitting belongs to.
  ({RecordEditController<T> controller, String recordId})? _joinedFor;

  /// Notes [joinedSitting] against the record shown, when it is a new one.
  void _noteJoinedFor() {
    final joined = joinedSitting;
    if (identical(joined, _joinedFor?.controller)) return;
    _joinedFor = joined == null
        ? null
        : (controller: joined, recordId: hostRecordId);
  }

  // What the host provides.

  RecordEditController<T>? _editController;

  /// Created on first use; the record page's own for a page that joined
  /// its sitting ([joinedSitting]).
  RecordEditController<T> get editController =>
      _joined ??
      (_editController ??= _newEditController(
        ProviderScope.containerOf(context, listen: false),
      ));

  /// The controller, or null before anything has asked for it.
  RecordEditController<T>? get maybeEditController =>
      _joined ?? _editController;

  /// Whether a sitting is in progress.
  bool get isSittingOpen => maybeEditController?.isUnlocked ?? false;

  /// The joined sitting this page listens to, so its bar follows it.
  RecordEditController<T>? _listenedJoined;

  /// This page's cards that were already open in the joined sitting when
  /// the page joined it: the record's page opened them, so Done leaves them
  /// open.
  Set<String> _openWhenJoined = const {};

  /// The record as a sitting just saved it, shown until the stored record
  /// has been read back. Without it the page would show the old values, and
  /// drop a card that was only just filled in, for the moment between the
  /// lock returning and the reload landing.
  T? justSavedRecord;

  /// Set while a leave the app asked about (another row, a tab, a quit)
  /// discards the sitting: that end is the leave's, and the page is going.
  bool sittingEndedByLeave = false;

  /// Makes the sitting's unsaved changes work the app asks about before a
  /// tab, a pane row or a quit leaves them.
  RecordSittingExitBlocker<T>? _exitBlocker;

  /// This page as the editing keys' target (Unlock, Save, Cancel).
  RecordEditShortcutTarget? _shortcutTarget;
  RecordEditShortcutTargets? _shortcutTargets;

  /// The record the page was showing when last built for one: another
  /// record ends the sitting.
  String? _hostedRecordId;

  RecordEditController<T> _newEditController(ProviderContainer container) {
    final controller = RecordEditController<T>(
      onSave: saveSitting,
      creating: isCreating,
      reread: (stored) => rereadStored(container, stored),
      // Each card's own check, asked at Save of open and closed cards.
      invalidCards: (session) => [
        for (final card in hostEditCards)
          if (card.isValid?.call(session) == false) card.id,
      ],
      onStart: (session) => onSittingStart(session, container),
    )..addListener(onEditChanged);
    _exitBlocker = RecordSittingExitBlocker<T>(
      controller: controller,
      guard: container.read(appExitGuardProvider),
      confirm: () async {
        if (!mounted) return false;
        // Set first: a discard locks, and tells the page, before
        // cancelSitting returns.
        sittingEndedByLeave = true;
        final left = await cancelSitting(context, controller);
        if (!left) sittingEndedByLeave = false;
        return left;
      },
      // The route the page is on, so leaving another page asks nothing.
      page: () => mounted ? recordSittingPageOf(context) : null,
    );
    return controller;
  }

  /// Called on every change of the controller. Redraws the page; a page
  /// with more to do on a change overrides it and calls `super`.
  void onEditChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _hostedRecordId = hostRecordId;
    _noteJoinedFor();
    final joined = _joined;
    if (joined != null) _followJoined(joined);
    _registerShortcutTarget(editController);
  }

  /// Listens to [joined] so the page's bar follows it, and notes which of
  /// the page's cards it already had open.
  void _followJoined(RecordEditController<T> joined) {
    _listenedJoined = joined..addListener(onEditChanged);
    _openWhenJoined = {
      for (final card in hostEditCards)
        if (joined.openCardIds.contains(card.id)) card.id,
    };
  }

  /// Makes this page the editing keys' target for [controller]. On a page
  /// that joined its record's sitting, Save and Cancel are Done, and there
  /// is no unlock.
  void _registerShortcutTarget(RecordEditController<T> controller) {
    final joined = identical(controller, _joined);
    final target = _shortcutTarget = RecordEditShortcutTarget(
      controller: controller,
      unlock: () {
        // A new record's page opens unlocked, and a joined page has no lock
        // of its own: there is nothing to unlock.
        if (joined || !offersEditing || isCreating) return;
        final stored = storedForUnlock;
        if (stored != null) controller.unlock(shownRecord(stored));
      },
      save: joined ? finishJoinedSitting : saveAndReport,
      cancel: joined ? finishJoinedSitting : cancelOrLeave,
      // The page in view: not under a page, sheet or menu.
      isCurrent: () =>
          offersEditing &&
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          isShortcutTargetInView,
    );
    final RecordEditShortcutTargets targets =
        _shortcutTargets ?? ref.read(recordEditShortcutTargetsProvider);
    _shortcutTargets = targets;
    targets.add(target);
  }

  /// The same page can be handed another record, keeping its state (the
  /// list pane does this with its detail). A sitting, and the copy of a
  /// record just saved, belong to the record they were made for and do not
  /// follow.
  ///
  /// A sitting that is being written cannot be ended here. One that goes
  /// through ends itself; one that fails is ended by [saveAndReport].
  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A page handed another sitting to join follows that one, and the keys
    // act on it.
    _noteJoinedFor();
    final joined = _joined;
    if (!identical(joined, _listenedJoined)) {
      _listenedJoined?.removeListener(onEditChanged);
      _listenedJoined = null;
      _openWhenJoined = const {};
      if (joined != null) {
        // The page now edits the record's sitting: one of its own ends, so
        // nothing unseen is left for the app to ask about on leaving.
        _editController?.lock();
        _followJoined(joined);
      }
      final target = _shortcutTarget;
      if (target != null) _shortcutTargets?.remove(target);
      _registerShortcutTarget(editController);
    }
    final id = hostRecordId;
    if (id == _hostedRecordId) return;
    _hostedRecordId = id;
    justSavedRecord = null;
    _editController?.lock();
  }

  /// Ends the page's editing. Call from the page's `dispose`.
  void disposeEditing() {
    _listenedJoined?.removeListener(onEditChanged);
    final target = _shortcutTarget;
    if (target != null) _shortcutTargets?.remove(target);
    _exitBlocker?.dispose();
    _editController?.dispose();
  }

  /// The record the cards display: the diver's working copy during a
  /// sitting, or the record as just saved, else [stored]. Either is used
  /// only when it is [stored]'s own record.
  T shownRecord(T stored) {
    final ours = maybeEditController?.session?.working ?? justSavedRecord;
    return ours != null && recordIdOf(ours) == recordIdOf(stored)
        ? ours
        : stored;
  }

  /// Keeps the sitting on top of the record as it is stored: a card the
  /// diver has not touched follows a change that arrives underneath. Call
  /// from `build` with the provider the page shows the record from.
  void followStored(ProviderListenable<AsyncValue<T?>> provider) {
    ref.listen(provider, (_, next) {
      // A reload in flight still carries the record it started from.
      if (next.isLoading) return;
      final record = next.valueOrNull;
      if (record == null) return;
      if (justSavedRecord != null) setState(() => justSavedRecord = null);
      // Only the sitting's own record. While a sitting is being written the
      // page can be handed another record, and that sitting has not ended
      // yet: it must not be moved onto a record it was not opened on.
      final controller = _editController;
      final session = controller?.session;
      if (session == null || recordIdOf(session.stored) != recordIdOf(record)) {
        return;
      }
      controller!.storedChanged(record);
    });
  }

  /// The Save button's word in the open sitting: Save when null. A sitting
  /// that ends otherwise names its own (a library reader's Send).
  String? get saveLabel => null;

  /// Asked before a Save that would write the open sitting: false leaves
  /// the sitting as it is and saves nothing, as a dialog the diver
  /// cancelled does. Not asked of a sitting with nothing to write, or with
  /// input to fix first, which the save ends or refuses as it is.
  Future<bool> beforeSave() async => true;

  /// Whether [beforeSave] is being asked: a second Save meanwhile (a double
  /// tap, the Save key pressed twice) does nothing.
  bool _askingBeforeSave = false;

  /// Saves the sitting, or creates the record, and says why when nothing
  /// was saved.
  Future<void> saveAndReport() async {
    if (isCreating) return saveNewRecord();
    if (_askingBeforeSave) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = editController;
    if (controller.saveWouldWrite) {
      _askingBeforeSave = true;
      try {
        if (!await beforeSave() || !mounted) return;
      } finally {
        _askingBeforeSave = false;
      }
    }
    final saved = await controller.save();
    if (saved || !mounted) return;
    // Refused for a field that holds text which is not a value: the card is
    // scrolled into view and its field says what is wrong with it.
    if (controller.refusedForInvalidInput) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordEdit_fixInvalid)),
      );
      return;
    }
    final error = controller.saveError;
    // The page was handed another record while this was being written,
    // when the sitting could not be ended (see [didUpdateWidget]). It ends
    // now, or it would stay open over a record it does not belong to.
    final session = controller.session;
    if (session != null && recordIdOf(session.stored) != hostRecordId) {
      controller.lock();
    }
    if (error == null) return;
    // A held write the database refused says what it was; anything else is
    // a save that failed.
    final message = error is RecordSittingRefusal
        ? error.message(l10n)
        : l10n.recordEdit_saveFailed;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Cancels the sitting, asking first when it has changes, or leaves a
  /// record not yet created.
  Future<void> cancelOrLeave() async {
    if (isCreating) return cancelNewRecord();
    await cancelSitting(context, editController);
  }

  /// The lock in the locked page's top bar. [shown] is the record as the
  /// page shows it, which just after a save is ahead of the one last read:
  /// a sitting must start from what the diver is looking at. [compact] is
  /// the list pane's smaller header.
  ///
  /// A page that joined its record's sitting ([joinedSitting]) has no lock
  /// of its own: once that sitting ends it only reads.
  Widget lockButton(T shown, {bool compact = false}) => _joined != null
      ? const SizedBox.shrink()
      : IconButton(
          icon: Icon(Icons.lock_outline, size: compact ? 20 : null),
          visualDensity: compact ? VisualDensity.compact : null,
          tooltip: context.l10n.recordEdit_unlockTooltip,
          onPressed: () => editController.unlock(shown),
        );

  /// Done on a page that joined its record's sitting: closes this page's
  /// open cards and goes back to the record's page, which keeps every
  /// change. A card that cannot close (unreadable input, or its own check
  /// fails) keeps the page here, showing itself, as closing it would.
  ///
  /// Cards the record's page already had open when this page joined stay
  /// open. While the sitting is busy (being saved, or a whole-record
  /// operation running) Done waits: nothing can close then.
  Future<void> finishJoinedSitting() async {
    final controller = _joined;
    if (controller == null || controller.isBusy) return;
    final ours = [
      for (final card in hostEditCards)
        if (controller.openCardIds.contains(card.id) &&
            !_openWhenJoined.contains(card.id))
          card.id,
    ];
    for (final id in ours) {
      controller.closeCard(id);
    }
    final stuck = ours.any(controller.openCardIds.contains);
    if (!mounted) return;
    if (stuck) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.recordEdit_fixInvalid)),
      );
      return;
    }
    await Navigator.of(context).maybePop();
  }

  /// Pushes a satellite page of this record (a passport, the cylinder
  /// board) from the page itself, its bar or its menu, handing it this
  /// page's sitting while one is open ([pushRecordSatellite]).
  Future<R?> pushSatellite<R>(
    Widget Function(RecordEditController<T>? joined) builder,
  ) => pushRecordSatellite<T, R>(
    context,
    builder: builder,
    sitting: maybeEditController,
  );

  /// The list pane's header row while unlocked: Cancel, the title, [menu]
  /// and Save, laid over the locked row.
  Widget editingPaneRow(T record, {required Widget menu}) {
    // A page that joined its record's sitting finishes with Done.
    if (_joined != null) {
      return RecordSatelliteBar(
        title: editingTitle(record),
        onDone: finishJoinedSitting,
      );
    }
    final controller = editController;
    return RecordEditPaneHeader(
      title: editingTitle(record),
      canSave: controller.isDirty,
      isSaving: controller.isSaving,
      isBusy: controller.isOperating,
      onCancel: cancelOrLeave,
      onSave: saveAndReport,
      menu: menu,
      saveLabel: saveLabel,
    );
  }

  /// The list pane with editing offered: [header] over the strip and
  /// [content], the whole of it in the sitting's scope, so the header
  /// follows the lock as the page does.
  Widget editPane({
    required Widget header,
    required T shown,
    required Widget content,
  }) {
    final controller = editController;
    final pane = RecordEditScope<T>(
      controller: controller,
      child: Column(
        children: [
          header,
          Expanded(
            child: AddStripLayout(
              strip: _editStrip(controller, shown),
              body: content,
            ),
          ),
        ],
      ),
    );
    // A page that joined its record's sitting asks nothing on leaving: the
    // changes stay in that sitting.
    if (_joined != null) return pane;
    return RecordEditLeaveGuard<T>(controller: controller, child: pane);
  }

  /// What lies under the edit bar while the record is unlocked: the cards
  /// it can add, and whatever the page pins below them ([belowStrip]).
  /// Nothing while locked.
  Widget _editStrip(RecordEditController<T> controller, T shown) {
    final strip = AddStrip(
      entries: controller.isUnlocked ? addStripEntries(shown) : const [],
      onAdd: controller.addCard,
    );
    if (!controller.isUnlocked) return strip;
    final below = belowStrip(shown);
    if (below == null) return strip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [strip, below],
    );
  }

  /// The full page with editing offered. [lockedBar] is the page's usual
  /// top bar and [content] its body; [shown] is the record the cards
  /// display.
  ///
  /// The body keeps one shape whether locked or unlocked, so unlocking does
  /// not rebuild the page beneath it or lose its scroll position.
  Widget editScaffold({
    required T record,
    required T shown,
    required PreferredSizeWidget lockedBar,
    required Widget content,
    List<Widget> unlockedActions = const [],
  }) {
    final joined = _joined;
    if (joined != null) {
      // The record's page owns the sitting: no leave check here, since
      // leaving keeps every change in it.
      return Scaffold(
        appBar: joined.isUnlocked
            ? RecordSatelliteBar(
                title: editingTitle(record),
                onDone: finishJoinedSitting,
              )
            : lockedBar,
        body: AddStripLayout(
          strip: _editStrip(joined, shown),
          body: RecordEditScope<T>(controller: joined, child: content),
        ),
      );
    }
    final controller = editController;
    return RecordEditLeaveGuard<T>(
      controller: controller,
      child: Scaffold(
        appBar: controller.isUnlocked
            ? RecordEditBar(
                title: editingTitle(record),
                canSave: controller.isDirty,
                isSaving: controller.isSaving,
                isBusy: controller.isOperating,
                actions: unlockedActions,
                onCancel: cancelOrLeave,
                onSave: saveAndReport,
                saveLabel: saveLabel,
              )
            : lockedBar,
        // The strip comes and goes as the page unlocks and locks, and as
        // cards are added and closed; the page under it stays where it is.
        body: AddStripLayout(
          strip: _editStrip(controller, shown),
          body: RecordEditScope<T>(controller: controller, child: content),
        ),
      ),
    );
  }
}
