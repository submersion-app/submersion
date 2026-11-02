import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/documents/dive_document.dart';
import 'package:submersion/features/agent_access/data/documents/dive_summary_document.dart';
import 'package:submersion/features/agent_access/data/documents/media_document.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// A tank read as a record of its own: the tank entity does not name its dive.
typedef _DiveTankRow = ({String diveId, DiveTank tank});

/// A custom field read as a record of its own, likewise.
typedef _DiveFieldRow = ({String diveId, DiveCustomField field});

final _viaDive = viaParent('dives', 'dive_id', rootScope(QuerySubject.dives));

/// Dives and their child records.
List<RecordEntry> diveEntries(RecordRepositories r) => [
  RecordEntity<Dive>(
    name: 'dives',
    table: 'dives',
    scope: rootScope(QuerySubject.dives),
    load: (ids, load) => _loadDives(r, ids, load),
    document: diveDocument,
    summaryKeys: const [],
    summarize: (ids, _) => _diveSummaries(r, ids),
    blocks: {
      'tanks': (dive, _) async => [
        for (final t in dive.tanks) diveTankDocument(t),
      ],
      'buddies': (dive, _) async => [
        for (final b in await r.buddies.getBuddiesForDive(dive.id))
          diveBuddyDocument(b),
      ],
      'tags': (dive, _) async => [for (final tag in dive.tags) tag.name],
      'types': (dive, _) async => [
        for (final id in dive.diveTypeIds)
          {'id': id, 'name': (await r.diveTypes.getDiveTypeById(id))?.name},
      ],
      'weights': (dive, _) async => [
        for (final w in dive.weights) diveWeightDocument(w),
      ],
      'sightings': (dive, _) async => [
        for (final s in await r.species.getSightingsForDive(dive.id))
          sightingDocument(s),
      ],
      'media': (dive, _) async => [
        for (final m in await r.media.getMediaForDive(dive.id))
          mediaDocument(m),
      ],
      'gear': (dive, _) async => [
        for (final g in dive.gear) diveGearDocument(g),
      ],
      'custom_fields': (dive, _) async => [
        for (final f in await r.customFields.getFieldsForDive(dive.id))
          diveCustomFieldDocument(f, diveId: dive.id),
      ],
      'gas_switches': (dive, _) async => [
        for (final s in await r.dives.getGasSwitchesForDive(dive.id))
          gasSwitchDocument(s),
      ],
      'events': (dive, _) async => [
        for (final e in await r.computers.getEventsForDive(dive.id))
          diveEventDocument(e),
      ],
      'data_sources': (dive, _) async => [
        for (final s in await r.dives.getDataSources(dive.id))
          diveDataSourceDocument(s),
      ],
      'scenarios': (dive, _) async => [
        for (final s in await r.diveScenarios.getScenariosForDive(dive.id))
          diveScenarioDocument(s),
      ],
      'profile': (dive, load) async => diveProfileDocument(
        dive.profile,
        load.profileOffset,
        load.profileLimit,
      ),
    },
  ),
  RecordEntity<_DiveTankRow>(
    name: 'dive_tanks',
    table: 'dive_tanks',
    scope: _viaDive,
    parentColumn: 'dive_id',
    orderBy: 'r0.dive_id, r0.tank_order',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'dive_tanks',
      parentColumn: 'dive_id',
      ids: ids,
      idOf: (row) => row.tank.id,
      byParents: (diveIds) async => {
        for (final dive in await r.dives.getDivesByIdsWithoutSamples(diveIds))
          dive.id: [
            for (final tank in dive.tanks) (diveId: dive.id, tank: tank),
          ],
      },
    ),
    document: (row) => diveTankDocument(row.tank, diveId: row.diveId),
    summaryKeys: const ['dive_id', 'name', 'volume_l', 'o2_fraction', 'role'],
  ),
  _diveChild<DiveWeight>(
    r,
    name: 'dive_weights',
    table: 'dive_weights',
    idOf: (w) => w.id,
    byDive: (ids) async => {
      for (final dive in await r.dives.getDivesByIdsWithoutSamples(ids))
        dive.id: dive.weights,
    },
    document: diveWeightDocument,
    summaryKeys: const ['dive_id', 'type', 'amount_kg', 'label'],
  ),
  _diveChild<Sighting>(
    r,
    name: 'sightings',
    table: 'sightings',
    idOf: (s) => s.id,
    byDive: (ids) => r.species.getSightingsForDives(ids),
    document: sightingDocument,
    summaryKeys: const ['dive_id', 'species_name', 'count'],
  ),
  _diveChild<_DiveFieldRow>(
    r,
    name: 'dive_custom_fields',
    table: 'dive_custom_fields',
    orderBy: 'r0.dive_id, r0.sort_order',
    idOf: (row) => row.field.id,
    byDive: (ids) async => {
      for (final e in (await r.customFields.getFieldsForDiveIds(ids)).entries)
        e.key: [for (final f in e.value) (diveId: e.key, field: f)],
    },
    document: (row) => diveCustomFieldDocument(row.field, diveId: row.diveId),
    summaryKeys: const ['dive_id', 'key', 'value'],
  ),
  _diveChild<GasSwitchWithTank>(
    r,
    name: 'gas_switches',
    table: 'gas_switches',
    orderBy: 'r0.dive_id, r0.timestamp',
    idOf: (s) => s.gasSwitch.id,
    byDive: (ids) => r.dives.getGasSwitchesForDives(ids),
    document: gasSwitchDocument,
    summaryKeys: const ['dive_id', 't_s', 'tank_name', 'o2_fraction'],
  ),
  _diveChild<DiveProfileEvent>(
    r,
    name: 'dive_events',
    table: 'dive_profile_events',
    orderBy: 'r0.dive_id, r0.timestamp',
    idOf: (e) => e.id,
    byDive: (ids) => r.computers.getEventsForDives(ids),
    document: diveEventDocument,
    summaryKeys: const ['dive_id', 't_s', 'type', 'severity'],
  ),
  RecordEntity<DiveScenario>(
    name: 'dive_scenarios',
    table: 'dive_scenarios',
    scope: _viaDive,
    parentColumn: 'dive_id',
    orderBy: 'r0.dive_id, r0.name',
    load: (ids, _) => loadEach(ids, r.diveScenarios.getScenario),
    document: diveScenarioDocument,
    summaryKeys: const ['dive_id', 'name', 'mode'],
  ),
  RecordEntity<MediaItem>(
    name: 'media',
    table: 'media',
    scope: mediaScope,
    parentColumn: 'dive_id',
    orderBy: 'r0.taken_at',
    load: (ids, _) => loadEach(ids, r.media.getMediaById),
    document: mediaDocument,
    summaryKeys: const [
      'dive_id',
      'source_type',
      'media_type',
      'captured_at',
      'caption',
    ],
  ),
];

/// As `MediaLibraryRepository`: a row on a dive follows the dive, and a row
/// on no dive is the library's, which every profile browses.
QueryScope mediaScope(String diverId, String alias) => (
  sql:
      '($alias.dive_id IS NULL OR $alias.dive_id IN '
      '(SELECT d.id FROM dives d WHERE d.diver_id = ?))',
  params: [diverId],
);

/// [media] without the rows [diverId] may not see. A shared site or item lists
/// every row attached to it, including rows on another diver's dive, which the
/// `media` entity refuses.
Future<List<MediaItem>> visibleMedia(
  RecordRepositories r,
  List<MediaItem> media,
  String diverId,
) async {
  final visible = await RecordReader(
    r.db,
  ).visibleRows('media', mediaScope, [for (final m in media) m.id], diverId);
  final allowed = visible.toSet();
  return [
    for (final m in media)
      if (allowed.contains(m.id)) m,
  ];
}

/// A child read by id through a repository that reads by dive.
RecordEntity<T> _diveChild<T>(
  RecordRepositories r, {
  required String name,
  required String table,
  required String Function(T) idOf,
  required Future<Map<String, List<T>>> Function(List<String>) byDive,
  required Map<String, Object?> Function(T) document,
  required List<String> summaryKeys,
  String orderBy = 'r0.dive_id',
}) => RecordEntity<T>(
  name: name,
  table: table,
  scope: _viaDive,
  parentColumn: 'dive_id',
  orderBy: orderBy,
  load: (ids, _) => loadChildren<T>(
    r.db,
    table: table,
    parentColumn: 'dive_id',
    ids: ids,
    idOf: idOf,
    byParents: byDive,
  ),
  document: document,
  summaryKeys: summaryKeys,
);

/// The profile is the one expensive part of a dive; decode it only when the
/// caller asked for that block, and load the rest in one batch.
Future<Map<String, Dive>> _loadDives(
  RecordRepositories r,
  List<String> ids,
  RecordLoad load,
) async {
  if (load.include.contains('profile')) {
    return loadEach(ids, r.dives.getDiveById);
  }
  return byId(await r.dives.getDivesByIdsWithoutSamples(ids), (d) => d.id);
}

Future<List<Map<String, Object?>>> _diveSummaries(
  RecordRepositories r,
  List<String> ids,
) async {
  final rows = <String, Map<String, Object?>>{};
  for (final chunk in seriesIdChunks(ids)) {
    for (final s in await r.dives.getSummariesByIds(chunk)) {
      rows[s.id] = diveSummaryDocument(s);
    }
  }
  return [for (final id in ids) ?rows[id]];
}
