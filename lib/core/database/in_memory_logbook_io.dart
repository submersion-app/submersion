import 'package:drift/native.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// An empty logbook in memory, with the app's own SQL functions.
AppDatabase openInMemoryLogbook() =>
    AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));

/// An empty local cache in memory.
LocalCacheDatabase openInMemoryLocalCache() =>
    LocalCacheDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
