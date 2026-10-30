import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';

/// One bound variable per id, well under SQLite's variable limit.
const _chunkSize = 500;

/// The facts a new trip learns from the dives [diveIds] (issue #3658): each
/// dive's time, trip, site region and country, and dive center name. One
/// lean query per chunk of ids, no profiles or tanks hydrated.
Future<List<SelectionDiveFacts>> selectionTripFacts(
  AppDatabase db,
  List<String> diveIds,
) async {
  final facts = <SelectionDiveFacts>[];
  for (var i = 0; i < diveIds.length; i += _chunkSize) {
    final chunk = diveIds.sublist(i, math.min(i + _chunkSize, diveIds.length));
    final marks = List.filled(chunk.length, '?').join(', ');
    final rows = await db
        .customSelect(
          // stats-scope-exempt: the diver's own selection, excluded dives
          // included.
          'SELECT d.id, d.dive_date_time, d.trip_id, s.region, s.country, '
          'c.name AS center_name FROM dives d '
          'LEFT JOIN dive_sites s ON s.id = d.site_id '
          'LEFT JOIN dive_centers c ON c.id = d.dive_center_id '
          'WHERE d.id IN ($marks)',
          variables: [for (final id in chunk) Variable.withString(id)],
          readsFrom: {db.dives, db.diveSites, db.diveCenters},
        )
        .get();
    facts.addAll([
      for (final r in rows)
        SelectionDiveFacts(
          diveId: r.read<String>('id'),
          diveDateTime: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('dive_date_time'),
            isUtc: true,
          ),
          tripId: r.readNullable<String>('trip_id'),
          siteRegion: r.readNullable<String>('region'),
          siteCountry: r.readNullable<String>('country'),
          diveCenterName: r.readNullable<String>('center_name'),
        ),
    ]);
  }
  return facts;
}

/// [selectionTripFacts] against the app's database.
Future<List<SelectionDiveFacts>> loadSelectionTripFacts(List<String> diveIds) =>
    selectionTripFacts(DatabaseService.instance.database, diveIds);
