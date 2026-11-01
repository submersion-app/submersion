import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/documents/media_document.dart';
import 'package:submersion/features/agent_access/data/documents/site_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// Sites, dive centers and their child records.
List<RecordEntry> siteEntries(RecordRepositories r) => [
  RecordEntity<DiveSite>(
    name: 'sites',
    table: 'dive_sites',
    scope: rootScope(QuerySubject.sites),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) async => byId(await r.sites.getSitesByIds(ids), (s) => s.id),
    document: siteDocument,
    summaryKeys: const ['name', 'country', 'region', 'max_depth_m', 'rating'],
    blocks: {
      'features': (site, _) async => [
        for (final f in await r.siteFeatures.getFeaturesForSite(site.id))
          siteFeatureDocument(f),
      ],
      'types': (site, _) async => [
        for (final t in await r.siteClassification.getTypesForSite(site.id))
          siteTypeDocument(t),
      ],
      'tags': (site, _) async => [
        for (final t in await r.siteClassification.getTagsForSite(site.id))
          t.name,
      ],
      'species': (site, _) async => [
        for (final e in await r.species.getExpectedSpeciesForSite(site.id))
          siteSpeciesDocument(e),
      ],
      'media': (site, _) async => [
        for (final m in await r.media.getMediaForSite(site.id))
          mediaDocument(m),
      ],
      'shares': (site, _) async => (await r.itemShares.storedProfileIds(
        SharedItemKind.site,
        site.id,
      )).toList(),
    },
  ),
  RecordEntity<SiteFeature>(
    name: 'site_features',
    table: 'site_features',
    scope: viaParent('dive_sites', 'site_id', rootScope(QuerySubject.sites)),
    parentColumn: 'site_id',
    orderBy: 'r0.site_id, r0.name',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'site_features',
      parentColumn: 'site_id',
      ids: ids,
      idOf: (f) => f.id,
      byParents: r.siteFeatures.getFeaturesForSites,
    ),
    document: siteFeatureDocument,
    summaryKeys: const ['site_id', 'type', 'name', 'depth_m'],
  ),
  RecordEntity<SiteTypeEntity>(
    name: 'site_types',
    table: 'site_types',
    scope: ownedOrBuiltIn(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, _) => loadEach(ids, r.siteTypes.getSiteTypeById),
    document: siteTypeDocument,
    summaryKeys: const ['name', 'is_built_in'],
  ),
  RecordEntity<DiveCenter>(
    name: 'centers',
    table: 'dive_centers',
    scope: rootScope(QuerySubject.centers),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.centers.getDiveCenterById),
    document: centerDocument,
    summaryKeys: const ['name', 'city', 'country', 'rating'],
    blocks: {
      'gear_notes': (center, _) async => [
        for (final n in await r.centerGearNotes.getForCenter(center.id))
          centerGearNoteDocument(n),
      ],
    },
  ),
  RecordEntity<DiveCenterGearNote>(
    name: 'center_gear_notes',
    table: 'dive_center_gear_notes',
    scope: viaParent(
      'dive_centers',
      'dive_center_id',
      rootScope(QuerySubject.centers),
    ),
    parentColumn: 'dive_center_id',
    orderBy: 'r0.dive_center_id, r0.noted_at DESC',
    load: (ids, _) => loadEach(ids, r.centerGearNotes.getById),
    document: centerGearNoteDocument,
    summaryKeys: const ['center_id', 'gear_type', 'verdict', 'noted_at'],
  ),
];
