import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/compaction/database_compaction_prefs.dart';
import 'package:submersion/core/database/compaction/database_space.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';

/// The open database's size and free pages, read when the Storage page
/// shows them.
// no-tick: autoDispose and read once per visit to the Storage page, whose
// refresh action invalidates it with the size rows.
final databaseSpaceProvider = FutureProvider.autoDispose<DatabaseSpace>(
  (ref) => readDatabaseSpace(DatabaseService.instance.database),
);

final databaseCompactionPrefsProvider = FutureProvider<DatabaseCompactionPrefs>(
  (ref) async => DatabaseCompactionPrefs(await SharedPreferences.getInstance()),
);
