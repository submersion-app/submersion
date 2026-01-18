#!/usr/bin/env dart

/// Exports dive sites from the Submersion database to JSON format
/// for tide constituent extraction.
///
/// Usage:
///   dart run scripts/tide/export_dive_sites.dart
///
/// Output: scripts/tide/dive_sites_export.json
library;

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:submersion/core/database/database.dart';

Future<void> main() async {
  // Find the database file
  final homeDir = Platform.environment['HOME'] ?? '';
  final possiblePaths = [
    // macOS app sandbox
    '$homeDir/Library/Containers/com.submersion.app/Data/Library/Application Support/com.submersion.app/submersion.db',
    // macOS development
    '$homeDir/Library/Application Support/com.submersion.app/submersion.db',
    // Linux
    '$homeDir/.local/share/submersion/submersion.db',
    // Current directory (for testing)
    'submersion.db',
  ];

  String? dbPath;
  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      dbPath = path;
      break;
    }
  }

  if (dbPath == null) {
    print('ERROR: Could not find database file.');
    print('Searched in:');
    for (final path in possiblePaths) {
      print('  - $path');
    }
    exit(1);
  }

  print('Found database: $dbPath');

  // Open database
  final database = AppDatabase(NativeDatabase(File(dbPath)));

  // Query all dive sites with coordinates
  final sites = await database.select(database.diveSites).get();

  final sitesWithCoords = sites
      .where((s) => s.latitude != null && s.longitude != null)
      .toList();

  print(
    'Found ${sites.length} total sites, ${sitesWithCoords.length} with coordinates',
  );

  if (sitesWithCoords.isEmpty) {
    print('No sites with GPS coordinates found.');
    await database.close();
    exit(0);
  }

  // Convert to JSON format expected by extraction script
  final output = sitesWithCoords.map((s) {
    return {
      'id': s.id,
      'name': s.name,
      'latitude': s.latitude,
      'longitude': s.longitude,
    };
  }).toList();

  // Write output
  final outputFile = File('scripts/tide/dive_sites_export.json');
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  print('Exported ${output.length} sites to: ${outputFile.path}');

  await database.close();
}
