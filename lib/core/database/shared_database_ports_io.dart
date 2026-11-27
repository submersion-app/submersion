import 'dart:ui' show IsolateNameServer;

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';

import 'package:submersion/core/database/background_database_connection.dart';

/// The main database's published name.
const kMainDatabasePortName = 'submersion.database.main';

/// The local cache database's published name.
const kLocalCacheDatabasePortName = 'submersion.database.local_cache';

/// Publishes [background]'s worker under [name], replacing any earlier one.
///
/// The name server is process-wide, so a pop-out window's engine finds it.
void publishDatabase(String name, BackgroundDatabaseConnection background) {
  IsolateNameServer.removePortNameMapping(name);
  IsolateNameServer.registerPortWithName(background.connectPort, name);
}

/// Withdraws the worker published under [name], if any.
void unpublishDatabase(String name) {
  IsolateNameServer.removePortNameMapping(name);
}

/// Connects to the worker published under [name] as another client, or
/// returns null when nothing is published.
///
/// Messages are serialized because the publishing engine is another isolate
/// group, which can only receive plain values. [interceptor] wraps the
/// connection; a pop-out passes one that refuses writes.
Future<DatabaseConnection?> connectToPublishedDatabase(
  String name, {
  QueryInterceptor? interceptor,
}) async {
  final port = IsolateNameServer.lookupPortByName(name);
  if (port == null) return null;
  final connection = await DriftIsolate.fromConnectPort(
    port,
    serialize: true,
  ).connect(singleClientMode: false);
  return interceptor == null
      ? connection
      : connection.interceptWith(interceptor);
}
