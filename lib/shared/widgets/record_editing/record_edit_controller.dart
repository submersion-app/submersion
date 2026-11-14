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
/// underneath. It does not notify for each further change to a card that
/// already has one: a page listening here must not rebuild on every
/// keystroke. An editor that needs every value listens to [session].
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

  void unlock(T stored) {
    if (isUnlocked) return;
    _toldChangedCardIds = const {};
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
    _saveError = null;
    _isSaving = false;
    notifyListeners();
  }

  void openCard(String cardId) {
    if (!isUnlocked) return;
    if (_openCardIds.add(cardId)) notifyListeners();
  }

  /// Closes [cardId]. A card that came from the Add strip and was given no
  /// change goes back to the strip.
  void closeCard(String cardId) {
    final session = _session;
    if (session == null) return;
    final wasOpen = _openCardIds.remove(cardId);
    final wasAdded =
        !session.changedCardIds.contains(cardId) &&
        _addedCardIds.remove(cardId);
    if (wasOpen || wasAdded) notifyListeners();
  }

  /// Brings in a card the page was leaving out, already open.
  void addCard(String cardId) {
    if (!isUnlocked) return;
    final added = _addedCardIds.add(cardId);
    final opened = _openCardIds.add(cardId);
    if (added || opened) notifyListeners();
  }

  /// Tells the sitting the stored record changed underneath it.
  void storedChanged(T stored) {
    final session = _session;
    if (session == null || _isSaving || stored == session.stored) return;
    session.rebase(stored);
    // Cards the diver has not touched now show other values, whether or not
    // the set of changed cards moved.
    _toldChangedCardIds = session.changedCardIds;
    notifyListeners();
  }

  void _onSessionChanged() {
    final changed = _session?.changedCardIds ?? const <String>{};
    if (setEquals(changed, _toldChangedCardIds)) return;
    _toldChangedCardIds = changed;
    notifyListeners();
  }

  /// Writes the sitting and locks. False when nothing was saved: the page
  /// was locked, a save was already running, or the write failed (see
  /// [saveError]); a failed save leaves the sitting exactly as it was.
  Future<bool> save() async {
    final session = _session;
    if (session == null || _isSaving) return false;
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
