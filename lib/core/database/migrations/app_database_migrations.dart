/// The migrations of [AppDatabase]: the upgrade ladder, the helpers its
/// rungs call, and the backstops that run on every open.
///
/// Kept out of `database.dart` on purpose. During code generation
/// drift_dev resolves the whole library that declares the database, so
/// every line there is paid for on each build (issue #2502).
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_backfill.dart';
import 'package:submersion/core/database/dive_type_uniqueness.dart';
import 'package:submersion/core/database/imported_computer_backfill.dart';
import 'package:submersion/core/database/performance_indexes.dart';
import 'package:submersion/core/database/profile_series_pack_coverage.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/core/database/profile_series_safety_stop_scrub.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';
import 'package:submersion/core/database/site_classification_uniqueness.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/database/equipment_share_uniqueness.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';
import 'package:submersion/core/database/tank_shared_computer_backfill.dart';
import 'package:submersion/core/constants/enums.dart';

part 'before_open.dart';
part 'helpers/buddy_migrations.dart';
part 'helpers/connection_migrations.dart';
part 'helpers/cylinder_migrations.dart';
part 'helpers/data_source_migrations.dart';
part 'helpers/derived_metrics_migrations.dart';
part 'helpers/dive_migrations.dart';
part 'helpers/dive_plan_migrations.dart';
part 'helpers/dive_profile_migrations.dart';
part 'helpers/diver_migrations.dart';
part 'helpers/equipment_migrations.dart';
part 'helpers/equipment_condition_migrations.dart';
part 'helpers/insight_migrations.dart';
part 'helpers/media_migrations.dart';
part 'helpers/pre_dive_migrations.dart';
part 'helpers/profile_series_history_migrations.dart';
part 'helpers/quality_migrations.dart';
part 'helpers/query_migrations.dart';
part 'helpers/safety_migrations.dart';
part 'helpers/service_migrations.dart';
part 'helpers/site_migrations.dart';
part 'helpers/support_migrations.dart';
part 'helpers/sync_migrations.dart';
part 'helpers/tag_migrations.dart';
part 'helpers/track_migrations.dart';
part 'helpers/trip_migrations.dart';
part 'helpers/weight_migrations.dart';
part 'ladder/rungs_v002_to_v029.dart';
part 'ladder/rungs_v030_to_v054.dart';
part 'ladder/rungs_v055_to_v071.dart';
part 'ladder/rungs_v072_to_v095.dart';
part 'ladder/rungs_v096_to_v148.dart';
part 'ladder/rungs_v149_to_v230.dart';
part 'ladder/rungs_v231_onward.dart';
part 'migration_strategy.dart';

/// Tables that carry a per-row Hybrid Logical Clock for cross-device conflict
/// resolution (plus sync_metadata for the device clock). Shared between the
/// v77 backfill (original add), the v82 backfill (recovery for databases that
/// landed at user_version = 77 via the schema-version collision with PR #302's
/// surface-interval index migration) and the v83 backfill (comprehensive
/// recovery for databases stranded past v77 by the wider set of sync-branch
/// version collisions; see the v82 and v83 rungs in
/// `ladder/rungs_v072_to_v095.dart`).
const List<String> _hlcTables = [
  'divers',
  'diver_settings',
  'buddies',
  'dive_centers',
  'trips',
  'liveaboard_detail_records',
  'trip_itinerary_days',
  'equipment',
  'equipment_sets',
  'equipment_attributes',
  'equipment_components',
  'dive_types',
  'dive_roles',
  'tank_presets',
  'weight_presets',
  'transmitters',
  'dive_computers',
  'tags',
  'courses',
  'dives',
  'dive_sites',
  'diver_weight_entries',
  'certifications',
  'service_records',
  'settings',
  'csv_presets',
  'view_configs',
  'sync_metadata',
  'media',
  'species',
  'field_presets',
  'quality_findings',
];

/// What the migrations of one connection did, for the getters that report
/// it.
///
/// An extension cannot declare instance fields, so the flags that were
/// fields of [AppDatabase] are held here, one record per database.
class _MigrationOutcome {
  bool droppedLegacySampleTables = false;
  bool recompressedRawBlobs = false;
  int rawBlobsLeftUncompressed = 0;
}

final _migrationOutcomes = Expando<_MigrationOutcome>();

extension _MigrationOutcomeOf on AppDatabase {
  _MigrationOutcome get _migrationOutcome =>
      _migrationOutcomes[this] ??= _MigrationOutcome();
}
