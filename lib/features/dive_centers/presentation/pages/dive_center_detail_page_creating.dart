part of 'dive_center_detail_page.dart';

/// A new dive centre on its page (issue #4527, phase 3, plan 11): the
/// page's hooks for the shared [RecordCreating]. It opens unlocked on a
/// seed ([newDiveCenterSeed]) with the header block, Contact and the Map
/// laid out open, and at Save creates the centre and its rental notes in
/// one transaction.
mixin _DiveCenterDetailPageCreating
    on
        ConsumerState<DiveCenterDetailPage>,
        RecordEditHost<DiveCenterDetailPage, DiveCenter>,
        RecordCreating<DiveCenterDetailPage, DiveCenter> {
  @override
  bool get isCreating => widget.newDiveCenter;

  @override
  Future<DiveCenter?> makeNewRecordSeed(RecordSeedRead read, String id) =>
      newDiveCenterSeed(read, id: id);

  @override
  List<String> newRecordLaidOut(DiveCenter seed) => newDiveCenterLaidOut;

  /// The centre and its held writes, in one transaction. A seed made with
  /// no diver takes the one active now, as the form does at Save.
  @override
  Future<DiveCenter> createRecord(EditSession<DiveCenter> session) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(diveCenterEditSaveServiceProvider);
    var center = session.applyTo(session.stored);
    if (center.diverId == null) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId != null) center = center.copyWith(diverId: diverId);
    }
    return service.create(
      center: center,
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// The centre list read again, as the form's add does.
  @override
  Future<void> Function(DiveCenter created) captureAfterRecordCreated() {
    final list = ref.read(diveCenterListNotifierProvider.notifier);
    return (_) => list.refresh();
  }

  @override
  String newRecordTitle(BuildContext context) =>
      context.l10n.diveCenters_title_add;

  @override
  String get newRecordLeaveLocation => '/dive-centers';

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
    title: context.l10n.diveCenters_title_add,
    body: context.l10n.diveCenters_error_generic('$error'),
  );
}
