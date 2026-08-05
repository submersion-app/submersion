import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

/// Loads the bundled emergency datasets (diver hotlines, EMS numbers,
/// starter chamber directory). Everything is asset-resident so the card
/// works with no signal; datasets ride app releases and every chamber entry
/// carries its verification date.
class EmergencyDataService {
  static EmergencyNumbers? _numbersCache;
  static List<EmergencyChamber>? _chambersCache;

  static Future<EmergencyNumbers> loadNumbers() async {
    if (_numbersCache != null) return _numbersCache!;
    final raw = await rootBundle.loadString(
      'assets/data/emergency_numbers.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final ems = json['ems'] as Map<String, dynamic>;
    _numbersCache = EmergencyNumbers(
      regions: [
        for (final r in json['regions'] as List)
          EmergencyRegion.fromJson(r as Map<String, dynamic>),
      ],
      defaultEms: ems['default'] as String,
      emsByCountry: (ems['byCountry'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
    return _numbersCache!;
  }

  static Future<List<EmergencyChamber>> loadBundledChambers() async {
    if (_chambersCache != null) return _chambersCache!;
    final raw = await rootBundle.loadString('assets/data/chambers.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _chambersCache = [
      for (final c in json['chambers'] as List)
        EmergencyChamber.fromBundledJson(c as Map<String, dynamic>),
    ];
    return _chambersCache!;
  }

  static void resetCacheForTesting() {
    _numbersCache = null;
    _chambersCache = null;
  }
}
