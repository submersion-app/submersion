import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/database_service.dart';
import 'features/dive_types/data/repositories/dive_type_repository.dart';
import 'features/marine_life/data/repositories/species_repository.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  await DatabaseService.instance.initialize();

  // Seed common species data
  final speciesRepository = SpeciesRepository();
  await speciesRepository.seedCommonSpecies();

  // Clean up orphaned custom dive types (those without a diver ID)
  final diveTypeRepository = DiveTypeRepository();
  await diveTypeRepository.deleteOrphanedCustomDiveTypes();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SubmersionApp(),
    ),
  );
}