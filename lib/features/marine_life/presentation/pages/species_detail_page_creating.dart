part of 'species_detail_page.dart';

/// A new species on the species page (issue #4527, phase 3, plan 11): the
/// page's hooks for the shared [RecordCreating]. It opens unlocked on a
/// seed ([newSpeciesSeed]) with the header block and Description laid out
/// open, and at Save creates the species as a custom one in one
/// transaction.
mixin _SpeciesDetailPageCreating
    on
        ConsumerState<SpeciesDetailPage>,
        RecordEditHost<SpeciesDetailPage, Species>,
        RecordCreating<SpeciesDetailPage, Species> {
  @override
  bool get isCreating => widget.newSpecies;

  @override
  Future<Species?> makeNewRecordSeed(RecordSeedRead read, String id) async =>
      newSpeciesSeed(id: id);

  @override
  List<String> newRecordLaidOut(Species seed) => newSpeciesLaidOut;

  @override
  Future<Species> createRecord(EditSession<Species> session) {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(speciesEditSaveServiceProvider);
    return service.create(
      species: session.applyTo(session.stored),
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  @override
  String newRecordTitle(BuildContext context) =>
      context.l10n.marineLife_speciesEdit_addTitle;

  @override
  String get newRecordLeaveLocation => '/species/manage';

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => (
    title: context.l10n.marineLife_speciesEdit_addTitle,
    body: error == null
        ? context.l10n.marineLife_speciesDetail_notFound
        : context.l10n.marineLife_speciesDetail_errorPrefix('$error'),
  );
}
