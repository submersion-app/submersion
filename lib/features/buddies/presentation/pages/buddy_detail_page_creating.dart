part of 'buddy_detail_page.dart';

/// A new buddy on the buddy page (issue #4527, phase 3, plan 11): the
/// page's hooks for the shared [RecordCreating]. It opens unlocked on a
/// seed ([newBuddySeed]) with the header block, Contact and Notes laid out
/// open, puts what the opener brought (a contact's name, email, phone and
/// photo) on as changes, and at Save creates the buddy and the
/// certifications its sitting holds in one transaction. The page pops the
/// buddy itself, as the form did: the buddy pickers select it.
mixin _BuddyDetailPageCreating
    on
        ConsumerState<BuddyDetailPage>,
        RecordEditHost<BuddyDetailPage, Buddy>,
        RecordCreating<BuddyDetailPage, Buddy> {
  @override
  bool get isCreating => widget.newBuddy != null;

  @override
  Future<Buddy?> makeNewRecordSeed(RecordSeedRead read, String id) =>
      newBuddySeed(read, id: id);

  @override
  List<String> newRecordLaidOut(Buddy seed) => newBuddyLaidOut;

  @override
  Future<void> applyNewRecordPrefill(EditSession<Buddy> session) async =>
      applyNewBuddyPrefill(session, widget.newBuddy?.seed);

  /// The buddy and its held writes, in one transaction. A seed made with
  /// no diver takes the one active now, as the form does at Save.
  @override
  Future<Buddy> createRecord(EditSession<Buddy> session) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(buddyEditSaveServiceProvider);
    var buddy = session.applyTo(session.stored);
    if (buddy.diverId == null) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId != null) buddy = buddy.copyWith(diverId: diverId);
    }
    return service.create(
      buddy: buddy,
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// The buddy list read again, as the form's add does.
  @override
  Future<void> Function(Buddy created) captureAfterRecordCreated() {
    final list = ref.read(buddyListNotifierProvider.notifier);
    return (_) => list.refresh();
  }

  /// The buddy itself: the buddy pickers select the one they get back.
  @override
  Object? newRecordResult(Buddy created) => created;

  @override
  String newRecordTitle(BuildContext context) => context.l10n.buddies_title_add;

  @override
  String get newRecordLeaveLocation => '/buddies';

  @override
  bool get newRecordEmbedded => widget.embedded;

  @override
  void Function(String id)? get onNewRecordCreated => widget.onCreated;

  @override
  VoidCallback? get onNewRecordCancelled => widget.onCreateCancelled;

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => (
    title: context.l10n.buddies_title_add,
    body: context.l10n.buddies_detail_error('$error'),
  );
}
