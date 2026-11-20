part of 'certification_detail_page.dart';

/// A new certification on its page (issue #4527, phase 3, plan 11): the
/// page's hooks for the shared [RecordCreating]. It opens unlocked on a
/// seed ([newCertificationSeed]) with Details, Dates and the card photos
/// laid out open, and at Save creates the certification and its card
/// images in one transaction. No currency rule matches a certification not
/// stored, and no course has earned it yet, so neither card is shown.
mixin _CertificationDetailPageCreating
    on
        ConsumerState<CertificationDetailPage>,
        RecordEditHost<CertificationDetailPage, Certification>,
        RecordCreating<CertificationDetailPage, Certification> {
  @override
  bool get isCreating => widget.newCertification;

  @override
  Future<Certification?> makeNewRecordSeed(RecordSeedRead read, String id) =>
      newCertificationSeed(read, id: id);

  @override
  List<String> newRecordLaidOut(Certification seed) => newCertificationLaidOut;

  /// The certification and its held writes, in one transaction. A seed
  /// made with no diver takes the one active now, as the form does.
  @override
  Future<Certification> createRecord(EditSession<Certification> session) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(certificationEditSaveServiceProvider);
    var certification = session.applyTo(session.stored);
    if (certification.diverId == null) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId != null) {
        certification = certification.copyWith(diverId: diverId);
      }
    }
    return service.create(
      certification: certification,
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// The certification list read again, as the form's add does.
  @override
  Future<void> Function(Certification created) captureAfterRecordCreated() {
    final list = ref.read(certificationListNotifierProvider.notifier);
    return (_) => list.refresh();
  }

  @override
  String newRecordTitle(BuildContext context) =>
      context.l10n.certifications_edit_appBar_add;

  @override
  String get newRecordLeaveLocation => '/certifications';

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
    title: context.l10n.certifications_edit_appBar_add,
    body: error == null
        ? context.l10n.certifications_detail_notFound
        : '${context.l10n.common_label_error}: $error',
  );
}
