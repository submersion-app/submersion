import 'package:submersion/features/agent_access/data/documents/logbook_documents.dart';
import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/agent_access/data/documents/track_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The records that stand alone: documents, incidents, plans, rules, tracks,
/// computers and the views a diver has saved.
List<RecordEntry> logbookEntries(RecordRepositories r) => [
  RecordEntity<PreDiveSession>(
    name: 'pre_dive_sessions',
    table: 'pre_dive_sessions',
    scope: ownedOrNull(),
    orderBy: 'r0.started_at DESC',
    load: (ids, _) => loadEach(ids, r.preDiveSessions.getSessionById),
    document: preDiveSessionDocument,
    summaryKeys: const ['template_name', 'started_at', 'status', 'dive_id'],
    blocks: {
      'items': (session, _) async => {
        'sections': [
          for (final s in await r.preDiveSessions.getSectionsForSession(
            session.id,
          ))
            preDiveSessionSectionDocument(s),
        ],
        'items': [
          for (final i in await r.preDiveSessions.getItemsForSession(
            session.id,
          ))
            preDiveSessionItemDocument(i),
        ],
      },
    },
  ),
  RecordEntity<Incident>(
    name: 'incidents',
    table: 'incidents',
    scope: ownedOrNull(),
    orderBy: 'r0.occurred_at DESC',
    load: (ids, _) => loadEach(ids, r.incidents.getIncidentById),
    document: incidentDocument,
    summaryKeys: const ['occurred_time', 'category', 'severity', 'dive_id'],
  ),
  RecordEntity<EmergencyChamber>(
    name: 'emergency_chambers',
    table: 'emergency_chambers',
    scope: ownedOrNull(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, load) async => byId(
      await r.emergencyChambers.getUserChambers(diverId: load.diverId),
      (c) => c.id,
    ),
    document: emergencyChamberDocument,
    summaryKeys: const ['name', 'country', 'phone'],
  ),
  RecordEntity<SavedQuery>(
    name: 'saved_queries',
    table: 'saved_queries',
    scope: ownedOrNull(),
    orderBy: 'r0.subject, r0.sort_order, r0.name',
    load: (ids, _) => loadEach(ids, r.savedQueries.getById),
    document: savedQueryDocument,
    summaryKeys: const ['subject', 'name'],
  ),
  // The planner lists every plan for every profile, whatever its diver_id.
  RecordEntity<DivePlan>(
    name: 'dive_plans',
    table: 'dive_plans',
    scope: everyone(),
    orderBy: 'r0.updated_at DESC',
    load: (ids, _) => loadEach(ids, r.divePlans.getPlan),
    document: divePlanDocument,
    summaryKeys: const ['name', 'mode', 'start_date_time', 'linked_dive_id'],
  ),
  RecordEntity<Document>(
    name: 'documents',
    table: 'documents',
    scope: owned(),
    orderBy: 'r0.title COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.documents.getById),
    document: documentDocument,
    summaryKeys: const ['title', 'type', 'issuer', 'expiry_date'],
    blocks: {
      'pages': (document, _) async => [
        for (final p in await r.documents.getPages(
          document.id,
          withBytes: false,
        ))
          documentPageDocument(p),
      ],
    },
  ),
  RecordEntity<Rule>(
    name: 'rules',
    table: 'rules',
    scope: owned(),
    orderBy: 'r0.subject, r0.sort_order, r0.name',
    load: (ids, load) async {
      final names = await NameIndexLoader(
        r.db,
      ).load(diverId: load.diverId, l10n: l10nForLocaleTag('en'));
      return loadEach(ids, (id) => r.rules.getById(id, names: names));
    },
    document: ruleDocument,
    summaryKeys: const ['subject', 'name', 'enabled'],
  ),
  RecordEntity<MediaSmartAlbum>(
    name: 'smart_albums',
    table: 'media_smart_albums',
    scope: everyone(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, _) async => byId(await r.smartAlbums.getAll(), (a) => a.id),
    document: smartAlbumDocument,
    summaryKeys: const ['name'],
  ),
  RecordEntity<SavedConnectionMap>(
    name: 'connection_maps',
    table: 'connection_maps',
    scope: owned(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, load) async =>
        byId(await r.connectionMaps.getAll(load.diverId), (m) => m.id),
    document: connectionMapDocument,
    summaryKeys: const ['name'],
  ),
  RecordEntity<CsvPreset>(
    name: 'csv_presets',
    table: 'csv_presets',
    scope: everyone(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) async =>
        byId(await r.csvPresets.getAllPresets(), (p) => p.id),
    document: csvPresetDocument,
    summaryKeys: const ['name'],
  ),
  RecordEntity<DiveComputer>(
    name: 'dive_computers',
    table: 'dive_computers',
    scope: owned(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.computers.getComputerById),
    document: diveComputerDocument,
    summaryKeys: const ['name', 'manufacturer', 'model', 'dive_count'],
  ),
  RecordEntity<DiverWeightEntry>(
    name: 'weight_entries',
    table: 'diver_weight_entries',
    scope: owned(),
    orderBy: 'r0.measured_at DESC',
    load: (ids, load) async => byId(
      await r.weightEntries.getEntriesForDiver(load.diverId),
      (e) => e.id,
    ),
    document: weightEntryDocument,
    summaryKeys: const ['measured_at', 'weight_kg'],
  ),
  RecordEntity<NavTrack>(
    name: 'nav_tracks',
    table: 'nav_tracks',
    scope: ownedOrNull(),
    parentColumn: 'dive_id',
    orderBy: 'r0.start_time DESC',
    load: (ids, load) => loadEach(
      ids,
      (id) => r.navTracks.getById(
        id,
        includePoints: load.include.contains('points'),
      ),
    ),
    document: navTrackDocument,
    summaryKeys: const ['name', 'dive_id', 'start_time', 'point_count'],
    blocks: {
      'points': (track, load) async => navTrackPointsDocument(
        track.points,
        load.profileOffset,
        load.profileLimit,
      ),
    },
  ),
  RecordEntity<GpsTrack>(
    name: 'gps_tracks',
    table: 'gps_tracks',
    scope: everyone(),
    orderBy: 'r0.start_time DESC',
    load: (ids, load) => loadEach(
      ids,
      (id) => r.gpsTracks.getTrack(
        id,
        includePoints: load.include.contains('points'),
      ),
    ),
    document: gpsTrackDocument,
    summaryKeys: const ['name', 'start_time', 'point_count'],
    blocks: {
      'points': (track, load) async => gpsTrackPointsDocument(
        track.points,
        load.profileOffset,
        load.profileLimit,
      ),
    },
  ),
];
