import 'package:drift/drift.dart';

import 'package:submersion/core/database/background_database_connection.dart';

/// The main database's published name.
const kMainDatabasePortName = 'submersion.database.main';

/// The local cache database's published name.
const kLocalCacheDatabasePortName = 'submersion.database.local_cache';

/// A browser has no second engine to share with.
void publishDatabase(String name, BackgroundDatabaseConnection background) {}

/// A browser has no second engine to share with.
void unpublishDatabase(String name) {}

/// A browser has no second engine to share with.
Future<DatabaseConnection?> connectToPublishedDatabase(
  String name, {
  QueryInterceptor? interceptor,
  Duration connectTimeout = const Duration(seconds: 5),
}) async => null;
