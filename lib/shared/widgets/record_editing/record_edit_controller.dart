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
/// It notifies when the lock, the open or added cards, the saving state, or
/// the set of cards with changes changes, and when the stored record changes
/// underneath. It does not notify for each further change to an open card
/// that already has one: a page listening here must not rebuild on every
/// keystroke, and an open card's editor listens to [session] for every
/// value. A card that is not open shows the page's copy of the record, so a
/// change to it from elsewhere (a rule that spans cards) does notify.
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

  /// Each changed card's [EditSession.revisionOf] when listeners were last
  /// told, or when the card was last opened or closed.
  Map<String, int> _toldRevisions = {};

  /// Fields holding text that cannot be read as a value, by card id, in the
  /// order each card first got one.
  final Map<String, Set<String>> _invalidFields = {};
  bool _refusedForInvalidInput = false;
  ({String cardId, int serial})? _revealRequest;

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

  /// Cards holding input that cannot be read as a value, such as `1.2.3` in
  /// a number field. Such text never reaches the [session], so a card that
  /// holds it stays open ([closeCard]) and the sitting cannot be saved
  /// ([save]) until it is fixed.
  Set<String> get invalidCardIds => Set.unmodifiable(_invalidFields.keys);

  /// The card last asked to scroll into view, with a serial that goes up on
  /// every request so the same card can be asked twice.
  ({String cardId, int serial})? get revealRequest => _revealRequest;

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

  void _requestReveal(String cardId) {
    _revealSerial++;
    _revealRequest = (cardId: cardId, serial: _revealSerial);
  }

  void unlock(T stored) {
    if (isUnlocked) return;
    _toldChangedCardIds = const {};
    _toldRevisions = {};
    _session = EditSession<T>(stored)..addListener(_onSessionChanged);
    notifyListeners();
  }

  /// Ends the sitting and discards whatever it held.
  void lock() {
    final session = _session;
    if (session == null) return;
    _dropSession(session);
    _openCardIds.clear();
    _addedCardIds.clear();
    _invalidFields.clear();
    _refusedForInvalidInput = false;
    _revealRequest = null;
    _saveError = null;
    _isSaving = false;
    notifyListeners();
  }

  void openCard(String cardId) {
    final session = _session;
    if (session == null) return;
    if (!_openCardIds.add(cardId)) return;
    _toldRevisions[cardId] = session.revisionOf(cardId);
    notifyListeners();
  }

  /// Closes [cardId]. A card that came from the Add strip and was given no
  /// change goes back to the strip. A card with unreadable input stays open
  /// and is asked to show itself instead ([revealRequest]).
  void closeCard(String cardId) {
    final session = _session;
    if (session == null) return;
    if (_invalidFields.containsKey(cardId)) {
      _requestReveal(cardId);
      notifyListeners();
      return;
    }
    final wasOpen = _openCardIds.remove(cardId);
    final wasAdded =
        !session.changedCardIds.contains(cardId) &&
        _addedCardIds.remove(cardId);
    if (!wasOpen && !wasAdded) return;
    // What was typed while it was open is drawn by this notification.
    _toldRevisions[cardId] = session.revisionOf(cardId);
    notifyListeners();
  }

  /// Brings in a card the page was leaving out, already open.
  void addCard(String cardId) {
    final session = _session;
    if (session == null) return;
    final added = _addedCardIds.add(cardId);
    final opened = _openCardIds.add(cardId);
    if (!added && !opened) return;
    _toldRevisions[cardId] = session.revisionOf(cardId);
    notifyListeners();
  }

  /// Tells the sitting the stored record changed underneath it.
  void storedChanged(T stored) {
    final session = _session;
    if (session == null || _isSaving || stored == session.stored) return;
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
    // A card that is not open changed again: nothing else will redraw it.
    final closedCardMoved = changed.any(
      (id) =>
          !_openCardIds.contains(id) &&
          session.revisionOf(id) != _toldRevisions[id],
    );
    if (!setMoved && !closedCardMoved) return;
    _rememberTold(session);
    notifyListeners();
  }

  /// Records what listeners are about to be told about the changed cards.
  void _rememberTold(EditSession<T> session) {
    final changed = session.changedCardIds;
    _toldChangedCardIds = changed;
    _toldRevisions = {for (final id in changed) id: session.revisionOf(id)};
  }

  /// Writes the sitting and locks. False when nothing was saved: the page
  /// was locked, a save was already running, a card holds unreadable input
  /// (see [refusedForInvalidInput]), or the write failed (see [saveError]).
  /// A save that did not happen leaves the sitting exactly as it was.
  Future<bool> save() async {
    final session = _session;
    if (session == null || _isSaving) return false;
    _refusedForInvalidInput = false;
    if (_invalidFields.isNotEmpty) {
      _refusedForInvalidInput = true;
      _requestReveal(_invalidFields.keys.first);
      notifyListeners();
      return false;
    }
    if (!session.isDirty) {
      lock();
      return true;
    }
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      await onSave(session);
    } catch (error) {
      // The page went away, or the sitting was discarded, while the write
      // was running: there is no one left to tell.
      if (!identical(_session, session)) return false;
      _saveError = error;
      _isSaving = false;
      notifyListeners();
      return false;
    }
    lock();
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
