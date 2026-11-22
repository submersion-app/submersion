import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart'
    hide DiveSite, SiteFeature, Species, Tag;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_save.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';
import 'site_detail_page_unlock_harness.dart';

/// A sitting that changes the site's collections is one History entry that
/// reverts as one, Cancel leaves nothing behind, and the locked page offers
/// no way to change them (issue #4527, phase 2, plan 3).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late Species manta;
  late Document permit;
  final changeLog = ChangeLogRepository();
  final at = DateTime.utc(2026);
  const site = DiveSite(
    id: 's1',
    diverId: 'me',
    name: 'Blue Hole',
    notes: 'Calm',
    location: GeoPoint(12, -68),
  );

  setUp(() async {
    // The upload queue a saved attachment joins reads the preferences.
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertDiver(db, 'me');
    await insertDiver(db, 'ana');
    await SiteRepository().createSite(site);
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) VALUES ('t1', 'To try', 0, 0, 0, 1)",
    );
    manta = await SpeciesRepository().createSpecies(
      commonName: 'Manta',
      category: SpeciesCategory.ray,
    );
    permit = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'me',
        owner: const DocumentOwner.personal(),
        type: DocumentType.other,
        title: 'Permit',
        createdAt: at,
        updatedAt: at,
      ),
      const [],
    );
    container = ProviderContainer();
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  /// A sitting on the site, started as the page starts one.
  Future<EditSession<DiveSite>> started() async {
    final session = EditSession<DiveSite>(site);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    startSiteSitting(session, container.read);
    await session.settled();
    return session;
  }

  /// The notes, a type, a tag, a species, a feature, sharing, a document
  /// and an attachment, each through its card's sitting function.
  void changeEverything(EditSession<DiveSite> session) {
    session.set(siteNotesField, 'Choppy');
    siteTypesList.set(session, [
      SiteTypeEntity(
        id: 'wreck',
        name: 'Wreck',
        isBuiltIn: true,
        createdAt: at,
        updatedAt: at,
      ),
    ]);
    siteTagsList.set(session, [
      Tag(id: 't1', name: 'To try', createdAt: at, updatedAt: at),
    ]);
    siteSpeciesList.set(session, [newSiteSpeciesEntry('s1', manta)]);
    addFeatureInSitting(
      session,
      const SiteFeature(
        id: 'held-f',
        siteId: 's1',
        typeName: 'mooring',
        latitude: 12.1,
        longitude: -68.1,
        name: 'Buoy',
      ),
    );
    siteSharing.set(
      session,
      const ItemSharing(profileIds: {'ana'}),
      actingDiverId: 'me',
    );
    attachDocument(session, permit);
    addMediaToSitting(session, [
      HeldMediaRow((
        item: MediaItem(
          id: 'held-m',
          siteId: 's1',
          mediaType: MediaType.document,
          originalFilename: 'map.pdf',
          takenAt: at,
          createdAt: at,
          updatedAt: at,
        ),
        enrichment: null,
      )),
    ]);
  }

  Future<List<ChangeLogOperation>> siteHistory() async {
    await changeLog.settleAll();
    return changeLog.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(rootTable: 'dive_sites', rootId: 's1'),
    );
  }

  /// Each collection as stored, for comparing before and after.
  Future<Map<String, Object?>> collections() async => {
    'notes': (await SiteRepository().getSiteById('s1'))!.notes,
    'types': [
      for (final t in await SiteClassificationRepository().getTypesForSite(
        's1',
      ))
        t.id,
    ],
    'tags': [
      for (final t in await SiteClassificationRepository().getTagsForSite('s1'))
        t.id,
    ],
    'species': [
      for (final e in await SpeciesRepository().getExpectedSpeciesForSite('s1'))
        e.speciesId,
    ],
    'features': [
      for (final f in await SiteFeatureRepository().getFeaturesForSite('s1'))
        f.name,
    ],
    'sharing': await ItemSharesRepository().sharingOf(
      SharedItemKind.site,
      's1',
    ),
    'document': (await DocumentRepository().getById(permit.id))!.owner,
    'media': [
      for (final m in await MediaRepository().getMediaForSite('s1')) m.id,
    ],
  };

  test('a sitting that changes several collections is one History entry '
      'and reverts as one', () async {
    final before = await collections();
    final session = await started();
    changeEverything(session);

    await saveSiteSitting(
      session,
      SiteEditSaveService(SiteRepository()),
      actingDiverId: 'me',
    );

    final saved = await collections();
    expect(saved['notes'], 'Choppy');
    expect(saved['types'], ['wreck']);
    expect(saved['tags'], ['t1']);
    expect(saved['species'], [manta.id]);
    expect(saved['features'], ['Buoy']);
    expect(saved['sharing'], const ItemSharing(profileIds: {'ana'}));
    expect(
      saved['document'],
      const DocumentOwner(DocumentOwnerKind.site, 's1'),
    );
    expect(saved['media'], ['held-m']);
    final entry = (await siteHistory()).single;

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(entry.id));
    await changeLog.settleAll();

    expect(await collections(), before);
  });

  test('Cancel after changing every collection writes nothing', () async {
    final before = await collections();
    final session = await started();
    changeEverything(session);

    // Cancel discards the sitting: its held writes never run.
    session.dispose();

    expect(await collections(), before);
    expect(await siteHistory(), isEmpty);
  });

  testWidgets('the locked page offers no way to change a collection', (
    tester,
  ) async {
    final l = AppLocalizationsEn();
    await pumpSitePage(
      tester,
      site: const DiveSite(id: 's1', diverId: 'me', name: 'Blue Hole'),
      extra: [
        mediaForSiteProvider('s1').overrideWith((_) async => <MediaItem>[]),
      ],
    );

    // Expected species: no edit button of its own.
    expect(
      find.byTooltip(l.marineLife_siteSection_editExpectedTooltip),
      findsNothing,
    );
    // Media: no add.
    expect(find.byTooltip(l.media_diveMediaSection_addTooltip), findsNothing);
    // Documents: Add keeps its room but neither shows nor works.
    final add = find.byKey(const ValueKey('documents-section-add'));
    expect(tester.widget<ButtonStyleButton>(add).onPressed, isNull);
    expect(add.hitTestable(), findsNothing);
  });
}
