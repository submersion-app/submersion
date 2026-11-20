import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

const _log = LoggerService('RecordCreating');

/// Reads a provider once, as `ref.read` does: what a new record's seed is
/// made from.
typedef RecordSeedRead = T Function<T>(ProviderListenable<T> provider);

/// A record not yet created, on its own page (issue #4527, phase 3, plan
/// 11): what every record type's new-record page does, whatever its record.
///
/// There is no form: the page opens unlocked on a **seed**, a record that
/// exists only in memory under the id it will be created with
/// ([newRecordId]), holding the defaults every new record of its type
/// gets ([makeNewRecordSeed]). The essential card and the starter set are
/// laid out open ([newRecordLaidOut]); what the opener brought goes on as
/// changes ([applyNewRecordPrefill]), so each shows its card's dot. Save
/// creates the record and everything the sitting held in one transaction
/// ([createRecord]), runs what follows a create ([afterRecordCreated]),
/// then leaves with the record ([leaveCreated]). Cancel leaves, asking
/// first once something was entered; a sitting that ends any other way
/// while the page is in view leaves too.
///
/// Mixed in after the page's own editing mixin, so that while creating its
/// overrides of [hostRecordId], [storedForUnlock], [editingTitle] and
/// [saveSitting] win, and otherwise hand on to the page's. The page says
/// whether it is creating ([isCreating]), builds on [shownStored] in place
/// of its stored record, and returns [newRecordWaiting] from `build` when
/// it is not null. This is the site's new-record page (phase 2, plan 6)
/// made generic.
mixin RecordCreating<W extends ConsumerStatefulWidget, T>
    on RecordEditHost<W, T> {
  // What the page supplies.

  /// The new record's starting record under [id], with the defaults every
  /// new record of its type gets; null when it cannot be made (a clone
  /// whose source has gone). A throw is a read that failed.
  Future<T?> makeNewRecordSeed(RecordSeedRead read, String id);

  /// The cards [seed] lays out open when the sitting opens on it. Asked
  /// again with the record as each change leaves it: a card it lays out
  /// anew opens then (a trip made a liveaboard lays out its Vessel).
  List<String> newRecordLaidOut(T seed);

  /// Puts what the opener brought on [session], each through its card's
  /// own function, so each is a change. Tracked: Save waits for it.
  Future<void> applyNewRecordPrefill(EditSession<T> session) async {}

  /// Creates the record from [session]: the type's save service, in one
  /// transaction with the sitting's held writes. Returns it as stored.
  Future<T> createRecord(EditSession<T> session);

  /// What follows a create once it has committed (a list read again, a
  /// reminder armed), made from what the page reads now, as Save is asked:
  /// it runs once the record exists even if the page has gone by then, so
  /// it must not read the page's `ref` later. A throw is logged: the
  /// record exists, and nothing that follows may read as a failed save.
  Future<void> Function(T created) captureAfterRecordCreated() => (_) async {};

  /// The unlocked bar's title for a new record.
  String newRecordTitle(BuildContext context);

  /// Where a full page goes once done when there is nothing under it.
  String get newRecordLeaveLocation;

  /// Whether the page is in a list pane, which is told of the end
  /// ([onNewRecordCreated], [onNewRecordCancelled]) rather than popped.
  bool get newRecordEmbedded => false;

  /// The pane's own: given the new record's id once it is created.
  void Function(String id)? get onNewRecordCreated => null;

  /// The pane's own: told when the page leaves without creating.
  VoidCallback? get onNewRecordCancelled => null;

  /// The texts for a new record that cannot open: its source has gone, or
  /// could not be read, with [error] (null when it has gone).
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  });

  /// Asked before a create that would write, as a stored record's page
  /// asks [beforeSave]: false creates nothing and leaves the sitting as it
  /// is, as a dialog the diver cancelled does. Asked after the opener's
  /// prefill and before what follows a create is captured, so what it
  /// decides can be part of both.
  Future<bool> beforeCreate(EditSession<T> session) async => true;

  /// What a full page pops with once created: the new id, unless the
  /// type's openers take the record itself.
  Object? newRecordResult(T created) => recordIdOf(created);

  /// Leaves once [created] exists: the pane is told its id; a full page
  /// pops with [newRecordResult].
  void leaveCreated(T created) {
    if (newRecordEmbedded) {
      onNewRecordCreated?.call(recordIdOf(created));
    } else {
      popNewRecord(newRecordResult(created));
    }
  }

  // What the mixin provides.

  /// The id the record will be created with, made once for the page.
  late final String newRecordId = const Uuid().v4();

  T? _seed;

  /// The seed, once made.
  T? get newRecordSeed => _seed;

  /// The seed could not be made: its source has gone, or [_seedError].
  bool _unavailable = false;
  Object? _seedError;

  /// The record as Save created it, while the page hands it on.
  T? _created;

  /// The sitting has been opened on the seed.
  bool _opened = false;

  /// The page is leaving: nothing opens or leaves again.
  bool _leaving = false;

  /// [beforeCreate] is being asked: a second Save meanwhile does nothing.
  bool _askingBeforeCreate = false;

  /// The app's own leave check ended the sitting: its navigation leaves.
  bool _endedByLeave = false;

  /// The record the page builds on: the seed while creating, else [stored].
  T? shownStored(T? stored) => isCreating ? _seed : stored;

  @override
  String get hostRecordId => isCreating ? newRecordId : super.hostRecordId;

  @override
  T? get storedForUnlock => isCreating ? _seed : super.storedForUnlock;

  @override
  String editingTitle(T record) =>
      isCreating ? newRecordTitle(context) : super.editingTitle(record);

  @override
  void initState() {
    super.initState();
    if (isCreating) _makeSeed();
  }

  Future<void> _makeSeed() async {
    // Once initState has returned: a seed may read the page's context (a
    // clone's name is in the diver's language).
    await null;
    if (!mounted) return;
    try {
      final seed = await makeNewRecordSeed(ref.read, newRecordId);
      if (!mounted) return;
      setState(() {
        _seed = seed;
        if (seed == null) _unavailable = true;
      });
      if (seed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openOnSeed());
      }
    } catch (error, stackTrace) {
      _log.error(
        'Making a new record failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _unavailable = true;
          _seedError = error;
        });
      }
    }
  }

  /// Opens the sitting on the seed with its cards laid out, then puts what
  /// the opener brought on it.
  void _openOnSeed() {
    final seed = _seed;
    if (!mounted || seed == null || _opened || _leaving) return;
    final controller = editController
      ..unlock(seed, laidOut: newRecordLaidOut(seed));
    final session = controller.session;
    if (session == null) return;
    setState(() => _opened = true);
    var laidOut = newRecordLaidOut(seed).toSet();
    // Heard from the sitting itself: the controller tells only when the
    // changed cards move, and a card already changed does not move them.
    session.addListener(() {
      if (session.isDisposed) return;
      final now = newRecordLaidOut(session.working).toSet();
      final anew = now.difference(laidOut);
      laidOut = now;
      if (anew.isNotEmpty) _openLaidOutAnew(session, anew);
    });
    session.track(applyNewRecordPrefill(session));
  }

  /// Opens the cards in [ids], laid out anew by a change to [session]'s
  /// record, once the change has been told: opening one tells again.
  void _openLaidOutAnew(EditSession<T> session, Set<String> ids) {
    final controller = editController;
    Future.microtask(() {
      if (!mounted || controller.session != session) return;
      for (final id in ids) {
        if (!controller.openCardIds.contains(id)) controller.openCard(id);
      }
    });
  }

  /// The page in place of the record while a new record has no sitting
  /// yet, cannot open, has been created, or is leaving; null otherwise.
  /// Call first in `build`.
  Widget? newRecordWaiting(BuildContext context) {
    if (!isCreating) return null;
    if (_unavailable) return _unavailableMessage(context);
    _leaveIfEnded(context);
    if (_opened && _created == null && !_leaving) return null;
    return _waiting(context, holdBack: _created != null);
  }

  Widget _unavailableMessage(BuildContext context) {
    final text = newRecordUnavailable(context, error: _seedError);
    final message = Center(child: Text(text.body));
    if (newRecordEmbedded) return message;
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: message,
    );
  }

  /// Waiting on the seed, or on the created record being handed on. While
  /// handing on ([holdBack]) Back waits: the record exists, and leaving
  /// then would leave its opener without it.
  Widget _waiting(BuildContext context, {required bool holdBack}) {
    const spinner = Center(child: CircularProgressIndicator());
    final page = newRecordEmbedded
        ? spinner
        : Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: !holdBack,
              title: Text(newRecordTitle(context)),
            ),
            body: spinner,
          );
    return holdBack ? PopScope(canPop: false, child: page) : page;
  }

  @override
  void onEditChanged() {
    // Read first: the page's own mixin clears the mark once it hears.
    if (isCreating && !isSittingOpen && sittingEndedByLeave) {
      _endedByLeave = true;
    }
    super.onEditChanged();
  }

  /// A sitting that ended without a create leaves, as Cancel does, once
  /// the page is in view: asked from `build`, which reads whether the page
  /// is current, so it is asked again on coming back.
  void _leaveIfEnded(BuildContext context) {
    if (!_opened || _created != null || _leaving) return;
    if (_endedByLeave || isSittingOpen) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving || _created != null || isSittingOpen) return;
      if (!(ModalRoute.of(this.context)?.isCurrent ?? true)) return;
      _leaveUncreated();
    });
  }

  /// The creating sitting's write: [createRecord], kept once it commits.
  @override
  Future<void> saveSitting(EditSession<T> session) async {
    if (!isCreating) return super.saveSitting(session);
    final created = await createRecord(session);
    // Kept even once the page has gone: what follows a create still runs.
    if (mounted) {
      setState(() => _created = created);
    } else {
      _created = created;
    }
  }

  /// Save: creates the record, runs what follows, then leaves with it. A
  /// save that is refused or fails says so, and the page stays with
  /// everything entered.
  @override
  Future<void> saveNewRecord() async {
    if (_created != null || _leaving || _askingBeforeCreate) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = editController;
    final session = controller.session;
    if (session != null && controller.saveWouldWrite) {
      _askingBeforeCreate = true;
      try {
        if (!await beforeCreate(session) || !mounted) return;
      } finally {
        _askingBeforeCreate = false;
      }
    }
    final afterCreated = captureAfterRecordCreated();
    final saved = await controller.save();
    if (!saved) {
      if (!mounted) return;
      final error = controller.saveError;
      if (controller.refusedForInvalidInput) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.recordEdit_fixInvalid)),
        );
      } else if (error != null) {
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
      return;
    }
    final created = _created;
    if (created == null) return;
    try {
      await afterCreated(created);
    } catch (error, stackTrace) {
      _log.error(
        'What follows creating ${recordIdOf(created)} failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    // Gone meanwhile (the app moved elsewhere): its pop would take the
    // page under it.
    if (!mounted || !(ModalRoute.of(context)?.isActive ?? true)) return;
    _leaving = true;
    leaveCreated(created);
  }

  /// Cancel, from the bar or Escape: asks when something was entered,
  /// then leaves without creating anything.
  @override
  Future<void> cancelNewRecord() async {
    if (_created != null || _leaving) return;
    if (!await cancelSitting(context, editController)) return;
    if (!mounted) return;
    _leaveUncreated();
  }

  void _leaveUncreated() {
    if (_leaving) return;
    setState(() => _leaving = true);
    if (newRecordEmbedded) {
      onNewRecordCancelled?.call();
    } else {
      popNewRecord(null);
    }
  }

  /// Leaves the full page with [result]: a plain pop, as a save leaves, or
  /// [newRecordLeaveLocation] when there is nothing under it. A page pushed
  /// without the router (another record's Documents card pushes one) is
  /// popped by it too, in a shell's navigator as well.
  void popNewRecord(Object? result) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).pop(result);
    } else if (router.canPop()) {
      context.pop(result);
    } else {
      context.go(newRecordLeaveLocation);
    }
  }
}

/// The held writes of [session], a new record's sitting, for its create to
/// run once the record's row is in, or null when it holds none: those held
/// to go before the record, then the rest, as a new site's create runs
/// them. Every held write points at the record, so all of them come after
/// its row on a create.
Future<void> Function()? heldWritesForCreate<T>(EditSession<T> session) {
  if (!session.hasHeldWrites) return null;
  return () async {
    await session.runHeldWrites(beforeRecord: true);
    await session.runHeldWrites();
  };
}
