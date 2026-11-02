import 'package:drift/drift.dart';

/// Turns `dives.weather_fetched_at` back into Unix seconds where it holds
/// milliseconds (v337, #4119), and returns how many dives it rewrote.
///
/// The bulk conditions fill wrote milliseconds until v337. A stored value says
/// which it is: seconds reach this cutoff in the year 5138, and every value
/// that fill wrote is far above it.
///
/// Cheap enough to run again after every inbound sync apply, which is how a
/// row from a peer below v337, or from a sync store still holding one, gets
/// the same repair. The sync stamp (`updated_at`, `hlc`) does not move: every
/// device runs this same rewrite, so they agree without a sync round.
///
/// Raw SQL, as the other ladder helpers, so it keeps compiling against any
/// later shape of the generated classes.
Future<int> repairWeatherFetchedAtSeconds(DatabaseConnectionUser db) =>
    db.customUpdate(
      'UPDATE dives SET weather_fetched_at = weather_fetched_at / 1000 '
      'WHERE weather_fetched_at >= 100000000000',
    );
