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
  RecordEditController({required this.onSave});

  final RecordSave<T> onSave;

  EditSession<T>? _session;
  bool _isSaving = false;
  Object? _saveError;
  final Set<String> _openCardIds = {};
  final Set<String> _addedCardIds = {};

  /// The cards that had changes when listeners were last told.
  Set<String> _toldChangedCardIds = const {};

  /// Each card's [EditSession.revisionOf] when listeners were last told, or
  /// when the card was last opened or closed.
  Map<String, int> _toldRevisions = {};

  T? _layoutRecord;

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

  void unlock(T stored) {
    if (isUnlocked) return;
    _toldChangedCardIds = const {};
    _toldRevisions = {};
    _session = EditSession<T>(stored)..addListener(_onSessionChanged);
    notifyListeners();
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
    _saveError = null;
    _isSaving = false;
    _storedDuringSave = null;
    notifyListeners();
  }

  /// Fixes the page's layout as the first card opens. Call before the card
  /// is added to the open ones.
  void _holdLayoutFor(EditSession<T> session) {
    if (_openCardIds.isEmpty) _layoutRecord = session.working;
  }

  /// Opens [cardId]'s editor. Like every change to the cards, it is
  /// refused while a save is running.
  void openCard(String cardId) {
    final session = _session;
    if (session == null || _isSaving) return;
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
    if (session == null || _isSaving) return;
    if (_invalidFields.containsKey(cardId)) {
      _requestRevealOfInvalid(cardId);
      notifyListeners();
      return;
    }
    final wasOpen = _openCardIds.remove(cardId);
    final wasAdded =
        !session.changedCardIds.contains(cardId) &&
        _addedCardIds.remove(cardId);
    if (!wasOpen && !wasAdded) return;
    // With the last editor closed the page follows the record again.
    if (_openCardIds.isEmpty) _layoutRecord = null;
    // What was typed while it was open is drawn by this notification.
    _toldRevisions[cardId] = session.revisionOf(cardId);
    notifyListeners();
  }

  /// Brings in a card the page was leaving out, already open, and asks for
  /// it to be scrolled into view ([revealRequest]): it takes its place in
  /// the page's order, which may be below what is on screen.
  void addCard(String cardId) {
    final session = _session;
    if (session == null || _isSaving) return;
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
    if (session == null || _isSaving) return false;
    _refusedForInvalidInput = false;
    if (_invalidFields.isNotEmpty) {
      _refusedForInvalidInput = true;
      _requestRevealOfInvalid(_invalidFields.keys.first);
      notifyListeners();
      return false;
    }
    if (!session.isDirty) {
      lock();
      return true;
    }
    _isSaving = true;
    _saveError = null;
    _storedDuringSave = null;
    // What is written is what the diver saw when they asked for it.
    session.freeze();
    notifyListeners();
    try {
      await onSave(session);
    } catch (error) {
      // The page went away, or the sitting was discarded, while the write
      // was running: there is no one left to tell.
      if (!identical(_session, session)) return false;
      session.thaw();
      _saveError = error;
      _isSaving = false;
      final missed = _storedDuringSave;
      _storedDuringSave = null;
      if (missed != null) session.rebase(missed.stored);
      _rememberTold(session);
      notifyListeners();
      return false;
    }
    _endSitting();
    return true;
  }

  void _dropSession(EditSession<T> session) {
    session
      ..removeListener(_onSessionChanged)
      ..dispose();
    _session = null;
  }

  @override
  void dispose() {
    final session = _session;
    if (session != null) _dropSession(session);
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
}
