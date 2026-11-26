import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Writes one sitting. Throws when nothing could be written.
typedef RecordSave<T> = Future<void> Function(EditSession<T> session);

/// The lock state of one record page, and its sitting while unlocked.
///
/// A page opens locked. [unlock] starts a sitting over the stored record;
/// [save] writes it and locks again; [lock] discards it. The lock is never
/// stored: every controller starts locked.
///
/// While a save is running the sitting is frozen: its values cannot change
/// and its cards cannot be opened, closed or added.
///
/// It notifies when the lock, the open or added cards, the saving state, or
/// the set of cards with changes changes, and when the stored record changes
/// underneath. It does not notify for each further change to an open card
/// that already has one: a page listening here must not rebuild on every
/// keystroke, and an open card's editor listens to [session] for every
/// value. A card that is not open shows the page's copy of the record, so a
/// change to what it shows (a rule that spans cards, or a value it shows
/// that an open card owns) does notify.
class RecordEditController<T> extends ChangeNotifier {
  RecordEditController({
    required this.onSave,
    this.trackedWorkTimeout = const Duration(seconds: 10),
    this.invalidCards,
    this.onStart,
    this.reread,
    this.creating = false,
  });

  /// Whether this controller's sittings create their record (issue #4527):
  /// the stored record is a seed ([EditSession.isNew]). A clean sitting has
  /// nothing to create, so [save] keeps it rather than ending it.
  final bool creating;

  /// See [creating].
  bool get isCreating => creating;

  final RecordSave<T> onSave;

  /// Told of each sitting as [unlock] starts it, before any card opens:
  /// what the record's cards need before they are checked (the dive's gas
  /// switches) is asked for here, whichever way the page was unlocked.
  final void Function(EditSession<T> session)? onStart;

  /// Reads the record as it is stored now, after a whole-record operation
  /// ([runOperation]) has written it; null when it no longer exists.
  final Future<T?> Function(T stored)? reread;

  /// The cards whose own check fails for the sitting, in page order. Asked
  /// of every card at [save], open or not: a value one card changes can
  /// leave another, closed, card unable to save. Such a card is opened and
  /// shown instead, and stays open until it passes ([closeCard]).
  final List<String> Function(EditSession<T> session)? invalidCards;

  /// How long [save] waits for work the sitting tracks
  /// ([EditSession.track]) before it writes without it. The page takes no
  /// input while it waits, so the wait must end.
  final Duration trackedWorkTimeout;

  EditSession<T>? _session;
  bool _isSaving = false;

  /// The sitting a whole-record operation has frozen while it runs, if
  /// any. It belongs to that sitting: ending it ends the operating state.
  EditSession<T>? _operatingOn;
  bool _disposed = false;
  Object? _saveError;
  final Set<String> _openCardIds = {};
  final Set<String> _addedCardIds = {};

  /// The cards that had changes when listeners were last told.
  Set<String> _toldChangedCardIds = const {};

  /// Each card's [EditSession.revisionOf] when listeners were last told, or
  /// when the card was last opened or closed.
  Map<String, int> _toldRevisions = {};

  T? _layoutRecord;

  /// What [layoutAnswer] was told while the layout has been held.
  final Map<String, bool> _layoutAnswers = {};

  /// Fields holding text that cannot be read as a value, by card id, in the
  /// order each card first got one.
  final Map<String, Set<String>> _invalidFields = {};
  bool _refusedForInvalidInput = false;

  /// The stored record that last arrived while a save was running, when
  /// the sitting could not follow it. A save that fails rebases onto it.
  ({T stored})? _storedDuringSave;

  ({String cardId, String? fieldId, int serial})? _revealRequest;

  /// Never reset, so a request in a later sitting is never mistaken for one
  /// a card has already answered.
  int _revealSerial = 0;

  bool get isUnlocked => _session != null;

  /// The sitting, non-null exactly while unlocked.
  EditSession<T>? get session => _session;

  /// Whether the sitting has unsaved changes. False while locked.
  bool get isDirty => _session?.isDirty ?? false;

  bool get isSaving => _isSaving;

  /// A whole-record operation is running ([runOperation]).
  bool get isOperating => _operatingOn != null;

  /// Saving, or running an operation: the page takes no input meanwhile.
  bool get isBusy => _isSaving || isOperating;

  /// Whether [save] would write the sitting now: unlocked, not busy, with a
  /// change, and nothing to fix first. Otherwise it ends the sitting with
  /// nothing to write, refuses it, or does nothing. Asked before anything is
  /// asked of the diver at Save (issue #4527), so no question is put for a
  /// save that will not happen.
  bool get saveWouldWrite {
    final session = _session;
    if (session == null || isBusy || !session.isDirty) return false;
    if (_invalidFields.isNotEmpty) return false;
    return (invalidCards?.call(session) ?? const []).isEmpty;
  }

  /// The last failed save. Cleared by the next save and by [lock].
  Object? get saveError => _saveError;

  Set<String> get openCardIds => Set.unmodifiable(_openCardIds);

  /// Cards brought in from the Add strip during this sitting.
  Set<String> get addedCardIds => Set.unmodifiable(_addedCardIds);

  /// The record the page lays itself out from while a card is open: the
  /// working record as it was when the first card opened. Null while every
  /// card is closed, when the page follows the working record.
  ///
  /// Which cards a page shows, and where, depends on what the record holds,
  /// and typing changes that. A card that appeared above an open editor
  /// would push it down the page under the diver's hands, so cards come and
  /// go only once the last editor has closed.
  T? get layoutRecord => _layoutRecord;

  /// What [ask] answers about the page's layout, asked once under [key] for
  /// as long as the layout is held ([layoutRecord]) and every time while it
  /// is not. For what a page lays itself out from that is not on the
  /// record, such as whether a card's own rows are empty: like a value of
  /// the record, it must not bring a card in above an open editor.
  bool layoutAnswer(String key, bool Function() ask) {
    if (_layoutRecord == null) return ask();
    return _layoutAnswers.putIfAbsent(key, ask);
  }

  /// Cards holding input that cannot be read as a value, such as `1.2.3` in
  /// a number field. Such text never reaches the [session], so a card that
  /// holds it stays open ([closeCard]) and the sitting cannot be saved
  /// ([save]) until it is fixed.
  Set<String> get invalidCardIds => Set.unmodifiable(_invalidFields.keys);

  /// What was last asked to scroll into view, if nothing has answered yet.
  ///
  /// With no field it is the card as a whole, which its frame answers: a
  /// card just added from the strip. With a field it is that field's row,
  /// which answers for itself: the unreadable input that stopped a card
  /// closing or the sitting saving, and which on a tall card can be far
  /// from the card's top. The serial goes up on every request, so the same
  /// thing can be asked for twice. Whoever answers calls [revealHandled].
  ({String cardId, String? fieldId, int serial})? get revealRequest =>
      _revealRequest;

  /// Withdraws the request numbered [serial], once what it names has
  /// scrolled into view. It does not notify: nothing is drawn from it.
  void revealHandled(int serial) {
    if (_revealRequest?.serial == serial) _revealRequest = null;
  }

  /// True when the last [save] was refused for unreadable input. Cleared by
  /// the next save and by [lock].
  bool get refusedForInvalidInput => _refusedForInvalidInput;

  /// Records whether [fieldId] on [cardId] holds text that cannot be read.
  ///
  /// It does not notify: a field calls it from its text listener and from
  /// its dispose, where a page may not rebuild, and nothing on the page
  /// draws the mark. The field shows its own message.
  void setFieldInvalid(String cardId, String fieldId, {required bool invalid}) {
    if (!isUnlocked) return;
    if (invalid) {
      (_invalidFields[cardId] ??= {}).add(fieldId);
      return;
    }
    final fields = _invalidFields[cardId];
    if (fields == null) return;
    fields.remove(fieldId);
    if (fields.isEmpty) _invalidFields.remove(cardId);
  }

  void _requestReveal(String cardId, {String? fieldId}) {
    _revealSerial++;
    _revealRequest = (cardId: cardId, fieldId: fieldId, serial: _revealSerial);
  }

  /// Asks for the first unreadable field of [cardId] to be shown.
  void _requestRevealOfInvalid(String cardId) =>
      _requestReveal(cardId, fieldId: _invalidFields[cardId]?.first);

  /// Starts a sitting on [stored]. Each card of [laidOut] is open from the
  /// first notification, brought in as [addCard] brings a card in but not
  /// scrolled to: a new record's starter cards (issue #4527).
  void unlock(T stored, {Iterable<String> laidOut = const []}) {
    if (isUnlocked) return;
    _toldChangedCardIds = const {};
    _toldRevisions = {};
    final session = _session = EditSession<T>(stored, isNew: creating)
      ..addListener(_onSessionChanged);
    for (final cardId in laidOut) {
      _holdLayoutFor(session);
      _addedCardIds.add(cardId);
      _openCardIds.add(cardId);
      _toldRevisions[cardId] = session.revisionOf(cardId);
    }
    // Told first, so the page shows the sitting whatever [onStart] does.
    notifyListeners();
    onStart?.call(session);
  }

  /// Ends the sitting and discards whatever it held. Refused while a save
  /// is running: the write would carry on with nothing tracking it, and a
  /// new sitting could start underneath it. The save ends the sitting
  /// itself when the write is done.
  void lock() {
    if (_isSaving) return;
    _endSitting();
  }

  void _endSitting() {
    final session = _session;
    if (session == null) return;
    _dropSession(session);
    _openCardIds.clear();
    _addedCardIds.clear();
    _invalidFields.clear();
    _refusedForInvalidInput = false;
    _revealRequest = null;
    _layoutRecord = null;
    _layoutAnswers.clear();
    _saveError = null;
    _isSaving = false;
    // An operation running on the sitting carries on, but the page is no
    // longer held for it: what it finds afterwards is not its sitting.
    _operatingOn = null;
    _storedDuringSave = null;
    notifyListeners();
  }

  /// Fixes the page's layout as the first card opens. Call before the card
  /// is added to the open ones.
  void _holdLayoutFor(EditSession<T> session) {
    if (_openCardIds.isEmpty) {
      _layoutRecord = session.working;
      _layoutAnswers.clear();
    }
  }

  /// Opens [cardId]'s editor. Like every change to the cards, it is
  /// refused while a save is running.
  void openCard(String cardId) {
    final session = _session;
    if (session == null || isBusy) return;
    if (_openCardIds.contains(cardId)) return;
    _holdLayoutFor(session);
    _openCardIds.add(cardId);
    _toldRevisions[cardId] = session.revisionOf(cardId);
    notifyListeners();
  }

  /// Closes [cardId]. A card that came from the Add strip and was given no
  /// change goes back to the strip. A card with unreadable input stays open
  /// and is asked to show itself instead ([revealRequest]).
  void closeCard(String cardId) {
    final session = _session;
    if (session == null || isBusy) return;
    if (_invalidFields.containsKey(cardId)) {
      _requestRevealOfInvalid(cardId);
      notifyListeners();
      return;
    }
    if (invalidCards?.call(session).contains(cardId) ?? false) {
      _requestReveal(cardId);
      notifyListeners();
      return;
    }
    final wasOpen = _openCardIds.remove(cardId);
    final wasAdded =
        !session.changedCardIds.contains(cardId) &&
        _addedCardIds.remove(cardId);
    if (!wasOpen && !wasAdded) return;
    // With the last editor closed the page follows the record again.
    if (_openCardIds.isEmpty) {
      _layoutRecord = null;
      _layoutAnswers.clear();
    }
    // What was typed while it was open is drawn by this notification.
    _toldRevisions[cardId] = session.revisionOf(cardId);
    notifyListeners();
  }

  /// Opens [cardId], bringing it in as [addCard] does when the page was
  /// leaving it out, and asks for it to be shown: a card that cannot be
  /// saved as it stands.
  void _openToShow(EditSession<T> session, String cardId) {
    if (!_openCardIds.contains(cardId)) {
      _holdLayoutFor(session);
      _addedCardIds.add(cardId);
      _openCardIds.add(cardId);
      _toldRevisions[cardId] = session.revisionOf(cardId);
    }
    _requestReveal(cardId);
  }

  /// Brings in a card the page was leaving out, already open, and asks for
  /// it to be scrolled into view ([revealRequest]): it takes its place in
  /// the page's order, which may be below what is on screen.
  void addCard(String cardId) {
    final session = _session;
    if (session == null || isBusy) return;
    if (_addedCardIds.contains(cardId) && _openCardIds.contains(cardId)) {
      return;
    }
    _holdLayoutFor(session);
    _addedCardIds.add(cardId);
    _openCardIds.add(cardId);
    _toldRevisions[cardId] = session.revisionOf(cardId);
    _requestReveal(cardId);
    notifyListeners();
  }

  /// Tells the sitting the stored record changed underneath it.
  ///
  /// While a save is running the sitting is frozen and cannot follow. The
  /// record is kept instead: a save that goes through ends the sitting, and
  /// one that fails gives it back rebased onto what arrived meanwhile.
  void storedChanged(T stored) {
    final session = _session;
    if (session == null) return;
    if (_isSaving) {
      _storedDuringSave = (stored: stored);
      return;
    }
    if (stored == session.stored) return;
    session.rebase(stored);
    // Cards the diver has not touched now show other values, whether or not
    // the set of changed cards moved.
    _rememberTold(session);
    notifyListeners();
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null) return;
    final changed = session.changedCardIds;
    final setMoved = !setEquals(changed, _toldChangedCardIds);
    // What a card that is not open shows has moved: its own value changed
    // by a rule, or a value it shows that another card owns. Nothing else
    // will redraw it.
    final closedCardMoved = session.revisedCardIds.any(
      (id) =>
          !_openCardIds.contains(id) &&
          session.revisionOf(id) != (_toldRevisions[id] ?? 0),
    );
    if (!setMoved && !closedCardMoved) return;
    _rememberTold(session);
    notifyListeners();
  }

  /// Records what listeners are about to be told about the cards.
  void _rememberTold(EditSession<T> session) {
    _toldChangedCardIds = session.changedCardIds;
    _toldRevisions = {
      for (final id in session.revisedCardIds) id: session.revisionOf(id),
    };
  }

  /// Writes the sitting and locks. False when nothing was saved: the page
  /// was locked, a save was already running, a card holds unreadable input
  /// (see [refusedForInvalidInput]), or the write failed (see [saveError]).
  /// A save that did not happen leaves the diver's changes exactly as they
  /// were; one whose write failed puts them on top of whatever was stored
  /// while it ran ([storedChanged]).
  Future<bool> save() async {
    final session = _session;
    if (session == null || isBusy) return false;
    _refusedForInvalidInput = false;
    if (_invalidFields.isNotEmpty) {
      _refusedForInvalidInput = true;
      _requestRevealOfInvalid(_invalidFields.keys.first);
      notifyListeners();
      return false;
    }
    // A sitting with nothing to write ends: a value stored failing a card's
    // check is not the diver's to fix before they can close the page.
    if (!session.isDirty) {
      // A record being created has nothing to create yet: the page stays.
      if (creating) return false;
      lock();
      return true;
    }
    final failing = invalidCards?.call(session) ?? const [];
    if (failing.isNotEmpty) {
      _refusedForInvalidInput = true;
      _openToShow(session, failing.first);
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _saveError = null;
    _storedDuringSave = null;
    notifyListeners();
    // Work the sitting started that the save depends on, such as the dive
    // types a picked site adds, lands first. The page takes no input
    // meanwhile: it reads [isSaving]. With nothing running the write starts
    // at once, as it always has. Work that has not answered within
    // [trackedWorkTimeout] is written without: the diver can set it again.
    final waited = !session.isSettled;
    if (waited) {
      await session.settled().timeout(trackedWorkTimeout, onTimeout: () {});
      // The page went away, or the sitting was discarded, while it waited:
      // nothing was written, and a sitting dispose kept for the write ends.
      if (_droppedWhileSaving(session)) return false;
      if (!identical(_session, session)) return false;
      // What landed meanwhile (switches read from the database, a set's
      // cylinders) is checked as the rest was.
      final failing = invalidCards?.call(session) ?? const [];
      if (failing.isNotEmpty) {
        _isSaving = false;
        _refusedForInvalidInput = true;
        // A record stored while it waited was kept for after the save.
        _followStoredDuringSave(session);
        _openToShow(session, failing.first);
        notifyListeners();
        return false;
      }
    }
    // What is written is what the diver saw when they asked for it.
    session.freeze();
    // Whatever was drawn during the wait drew the sitting as it could
    // still change: tell it that it no longer can.
    if (waited) notifyListeners();
    try {
      await onSave(session);
    } catch (error) {
      // The page went away, or the sitting was discarded, while the write
      // was running: there is no one left to tell.
      if (_droppedWhileSaving(session)) return false;
      if (!identical(_session, session)) return false;
      session.thaw();
      _saveError = error;
      _isSaving = false;
      _followStoredDuringSave(session);
      notifyListeners();
      return false;
    }
    if (_droppedWhileSaving(session)) return true;
    _endSitting();
    return true;
  }

  /// Runs a whole-record operation (delete, re-parse and the like), which
  /// writes the record at once as its own History entry (issue #4527).
  ///
  /// Refused, returning false without running it, unless the page is
  /// unlocked with nothing to save and no save or other operation running.
  /// While it runs the sitting is frozen and the page takes no input
  /// ([isBusy]). [operation] answers whether it wrote anything. When it did,
  /// the record is read again ([reread]) and a fresh sitting starts on it
  /// ([retake]), or the page locks when the record is gone. When it did not,
  /// or throws, the sitting carries on as it was; a throw is passed on. A
  /// read that throws after a write locks the page and is passed on too: the
  /// sitting's copy is from before the write, and a Save from it would put
  /// the old record back.
  /// False also when the controller was disposed meanwhile.
  Future<bool> runOperation(Future<bool> Function() operation) async {
    final session = _session;
    if (session == null || isBusy || session.isDirty || _disposed) {
      return false;
    }
    _operatingOn = session;
    session.freeze();
    notifyListeners();
    try {
      final wrote = await operation();
      if (_disposed) return false;
      final reread = this.reread;
      if (!wrote || reread == null || !identical(_session, session)) {
        return true;
      }
      final T? fresh;
      try {
        fresh = await reread(session.stored);
      } catch (_) {
        if (!_disposed && identical(_session, session)) _endSitting();
        rethrow;
      }
      if (_disposed) return false;
      if (!identical(_session, session)) return true;
      _operatingOn = null;
      session.thaw();
      if (fresh == null) {
        _endSitting();
      } else {
        _restart(fresh);
      }
      return true;
    } finally {
      // Only this operation's own hold: a lock may have ended it, and a
      // later sitting may be running an operation of its own.
      if (identical(_operatingOn, session)) {
        _operatingOn = null;
        if (!session.isDisposed) session.thaw();
        if (!_disposed) notifyListeners();
      }
    }
  }

  /// Starts a fresh sitting on [stored] in place of the current one, which
  /// has nothing to save. The page stays unlocked throughout: it is never
  /// told it locked. Refused while locked, with unsaved changes, or busy.
  void retake(T stored) {
    final session = _session;
    if (session == null || session.isDirty || isBusy) return;
    _restart(stored);
  }

  void _restart(T stored) {
    final old = _session;
    if (old != null) {
      old
        ..removeListener(_onSessionChanged)
        ..dispose();
    }
    _openCardIds.clear();
    _addedCardIds.clear();
    _invalidFields.clear();
    _refusedForInvalidInput = false;
    _revealRequest = null;
    _layoutRecord = null;
    _layoutAnswers.clear();
    _saveError = null;
    _storedDuringSave = null;
    _toldChangedCardIds = const {};
    _toldRevisions = {};
    final session = _session = EditSession<T>(stored, isNew: creating)
      ..addListener(_onSessionChanged);
    notifyListeners();
    onStart?.call(session);
  }

  /// The sitting of a controller disposed while [session] was being
  /// written: kept until the write ended, since its held writes read it.
  EditSession<T>? _endsAfterSave;

  /// Ends [session] if the controller was disposed while it was written.
  bool _droppedWhileSaving(EditSession<T> session) {
    if (!identical(_endsAfterSave, session)) return false;
    _endsAfterSave = null;
    session.dispose();
    return true;
  }

  /// A save that did not go through gives the sitting the record stored
  /// while it ran ([storedChanged]), which it could not follow then.
  void _followStoredDuringSave(EditSession<T> session) {
    final missed = _storedDuringSave;
    _storedDuringSave = null;
    if (missed != null) session.rebase(missed.stored);
    _rememberTold(session);
  }

  void _dropSession(EditSession<T> session) {
    session
      ..removeListener(_onSessionChanged)
      ..dispose();
    _session = null;
  }

  @override
  void dispose() {
    _disposed = true;
    final session = _session;
    if (session != null && _isSaving) {
      // Its write is running and still reads it: it ends when that does.
      session.removeListener(_onSessionChanged);
      _session = null;
      _endsAfterSave = session;
    } else if (session != null) {
      _dropSession(session);
    }
    super.dispose();
  }
}

/// Hands a page's [RecordEditController] to its cards.
class RecordEditScope<T> extends InheritedNotifier<RecordEditController<T>> {
  const RecordEditScope({
    super.key,
    required RecordEditController<T> controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller of the nearest scope for [T], or null when the page
  /// offers no editing. Rebuilds the caller when the controller changes.
  static RecordEditController<T>? maybeOf<T>(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RecordEditScope<T>>()
      ?.notifier;

  /// The controller of the nearest scope for [T], for a widget built only on
  /// a page that offers editing. Rebuilds the caller when it changes.
  static RecordEditController<T> of<T>(BuildContext context) {
    final controller = maybeOf<T>(context);
    assert(controller != null, 'No RecordEditScope<$T> above this widget');
    return controller!;
  }
}
