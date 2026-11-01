import 'package:submersion/core/services/sync/child_column_clears.dart';

/// Tables whose sync entity is not their name in camel case. A test pins
/// this to `SyncRepository.hlcTargets`.
const Map<String, String> _entityExceptions = {
  'liveaboard_detail_records': 'liveaboardDetails',
  'trip_itinerary_days': 'itineraryDays',
};

/// The sync entity type of [table].
String changeLogEntityType(String table) =>
    _entityExceptions[table] ?? columnJsonKey(table);
