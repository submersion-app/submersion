import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Data volume profile for performance testing.
enum DataProfile { light, realistic, heavy }

/// Summary of all generated data for verification.
class GeneratedDataSummary {
  final String diverId;
  final int diveCount;
  final int siteCount;
  final int profilePointCount;
  final int tankCount;
  final int tagCount;
  final int buddyCount;
  final int equipmentCount;
  final int sightingCount;
  final Duration generationTime;

  const GeneratedDataSummary({
    required this.diverId,
    required this.diveCount,
    required this.siteCount,
    required this.profilePointCount,
    required this.tankCount,
    required this.tagCount,
    required this.buddyCount,
    required this.equipmentCount,
    required this.sightingCount,
    required this.generationTime,
  });
}

/// Generates synthetic dive data for performance testing.
///
/// Supports three volume profiles: light (100 dives), realistic (5000),
/// and heavy (10000). Uses a fixed random seed for reproducibility.
class PerformanceDataGenerator {
  final DataProfile profile;
  final _uuid = const Uuid();
  final Random _random;
  var _profilePointCounter = 0;

  AppDatabase get _db => DatabaseService.instance.database;

  PerformanceDataGenerator(this.profile) : _random = Random(42);

  int get _diveCount => switch (profile) {
    DataProfile.light => 100,
    DataProfile.realistic => 5000,
    DataProfile.heavy => 10000,
  };

  int get _siteCount => switch (profile) {
    DataProfile.light => 30,
    DataProfile.realistic => 2000,
    DataProfile.heavy => 4000,
  };

  /// Generate all synthetic data and return a summary.
  Future<GeneratedDataSummary> generate() async {
    final stopwatch = Stopwatch()..start();

    final diverId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Step 1: Create the diver
    await _createDiver(diverId, now);

    // Step 2: Create reference data pools
    final tagIds = await _generateTags(diverId, now);
    final buddyIds = await _generateBuddies(diverId, now);
    final equipmentIds = await _generateEquipment(diverId, now);
    final siteIds = await _generateSites(diverId, now);
    final speciesIds = await _ensureSpecies();

    // Step 3: Generate dives with all related data
    final diveStats = await _generateDives(
      diverId: diverId,
      siteIds: siteIds,
      tagIds: tagIds,
      buddyIds: buddyIds,
      equipmentIds: equipmentIds,
      speciesIds: speciesIds,
      now: now,
    );

    stopwatch.stop();

    return GeneratedDataSummary(
      diverId: diverId,
      diveCount: _diveCount,
      siteCount: _siteCount,
      profilePointCount: diveStats.profilePointCount,
      tankCount: diveStats.tankCount,
      tagCount: tagIds.length,
      buddyCount: buddyIds.length,
      equipmentCount: equipmentIds.length,
      sightingCount: diveStats.sightingCount,
      generationTime: stopwatch.elapsed,
    );
  }

  // --------------------------------------------------------------------------
  // Diver
  // --------------------------------------------------------------------------

  Future<void> _createDiver(String diverId, int now) async {
    await _db
        .into(_db.divers)
        .insert(
          DiversCompanion(
            id: Value(diverId),
            name: const Value('Performance Test Diver'),
            email: const Value('perf@test.com'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // --------------------------------------------------------------------------
  // Tags
  // --------------------------------------------------------------------------

  Future<List<String>> _generateTags(String diverId, int now) async {
    final companions = <TagsCompanion>[];
    for (var i = 1; i <= 15; i++) {
      final id = _uuid.v4();
      final color =
          '#${_random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      companions.add(
        TagsCompanion(
          id: Value(id),
          diverId: Value(diverId),
          name: Value('Tag $i'),
          color: Value(color),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    await _batchInsert(_db.tags, companions);
    return companions.map((c) => c.id.value).toList();
  }

  // --------------------------------------------------------------------------
  // Buddies
  // --------------------------------------------------------------------------

  Future<List<String>> _generateBuddies(String diverId, int now) async {
    const certLevels = [
      'Open Water',
      'Advanced Open Water',
      'Rescue Diver',
      'Divemaster',
      'Instructor',
    ];
    final companions = <BuddiesCompanion>[];
    for (var i = 1; i <= 20; i++) {
      final id = _uuid.v4();
      companions.add(
        BuddiesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          name: Value('Buddy $i'),
          certificationLevel: Value(certLevels[i % certLevels.length]),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    await _batchInsert(_db.buddies, companions);
    return companions.map((c) => c.id.value).toList();
  }

  // --------------------------------------------------------------------------
  // Equipment
  // --------------------------------------------------------------------------

  Future<List<String>> _generateEquipment(String diverId, int now) async {
    const types = ['regulator', 'bcd', 'wetsuit', 'fins', 'mask', 'computer'];
    final companions = <EquipmentCompanion>[];
    for (var i = 1; i <= 30; i++) {
      final id = _uuid.v4();
      final type = types[i % types.length];
      companions.add(
        EquipmentCompanion(
          id: Value(id),
          diverId: Value(diverId),
          name: Value('$type $i'),
          type: Value(type),
          brand: Value('Brand ${i % 5}'),
          model: Value('Model ${i % 10}'),
          status: const Value('active'),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    await _batchInsert(_db.equipment, companions);
    return companions.map((c) => c.id.value).toList();
  }

  // --------------------------------------------------------------------------
  // Sites
  // --------------------------------------------------------------------------

  Future<List<String>> _generateSites(String diverId, int now) async {
    final countries = _buildCountryList();
    final companions = <DiveSitesCompanion>[];
    const difficulties = ['Beginner', 'Intermediate', 'Advanced', 'Technical'];

    for (var i = 0; i < _siteCount; i++) {
      final id = _uuid.v4();
      final country = countries[i % countries.length];
      final hasGps = _random.nextDouble() < 0.8;

      companions.add(
        DiveSitesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          name: Value('Site ${i + 1}'),
          description: Value('A dive site for performance testing (#${i + 1})'),
          latitude: Value(hasGps ? _random.nextDouble() * 180 - 90 : null),
          longitude: Value(hasGps ? _random.nextDouble() * 360 - 180 : null),
          minDepth: Value(5.0 + _random.nextDouble() * 10),
          maxDepth: Value(20.0 + _random.nextDouble() * 40),
          difficulty: Value(difficulties[_random.nextInt(difficulties.length)]),
          country: Value(country.$1),
          region: Value(country.$2[_random.nextInt(country.$2.length)]),
          rating: Value(1.0 + _random.nextDouble() * 4),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    await _batchInsert(_db.diveSites, companions);
    return companions.map((c) => c.id.value).toList();
  }

  // --------------------------------------------------------------------------
  // Species (ensure at least some exist for sightings)
  // --------------------------------------------------------------------------

  Future<List<String>> _ensureSpecies() async {
    // Check if any built-in species exist
    final existingRows =
        await (_db.select(_db.species)
              ..where((t) => t.isBuiltIn.equals(true))
              ..limit(50))
            .get();

    if (existingRows.isNotEmpty) {
      return existingRows.map((s) => s.id).toList();
    }

    // In test environments, built-in species may not be seeded.
    // Create a small set for sighting references.
    final companions = <SpeciesCompanion>[];
    const speciesNames = [
      ('Clownfish', 'fish'),
      ('Manta Ray', 'fish'),
      ('Whale Shark', 'fish'),
      ('Sea Turtle', 'reptile'),
      ('Octopus', 'invertebrate'),
      ('Moray Eel', 'fish'),
      ('Lionfish', 'fish'),
      ('Seahorse', 'fish'),
      ('Nudibranch', 'invertebrate'),
      ('Barracuda', 'fish'),
    ];

    final ids = <String>[];
    for (final (name, category) in speciesNames) {
      final id = _uuid.v4();
      ids.add(id);
      companions.add(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(name),
          category: Value(category),
          isBuiltIn: const Value(true),
        ),
      );
    }
    await _batchInsert(_db.species, companions);
    return ids;
  }

  // --------------------------------------------------------------------------
  // Dives (with profiles, tanks, tags, buddies, equipment, sightings)
  // --------------------------------------------------------------------------

  Future<_DiveGenerationStats> _generateDives({
    required String diverId,
    required List<String> siteIds,
    required List<String> tagIds,
    required List<String> buddyIds,
    required List<String> equipmentIds,
    required List<String> speciesIds,
    required int now,
  }) async {
    var totalProfilePoints = 0;
    var totalTanks = 0;
    var totalSightings = 0;

    // Pre-compute the date range: 10 years back from 2024
    final baseDate = DateTime(2024, 12, 31);
    const tenYearsDays = 3650;

    // Process dives in batches to manage memory
    const diveBatchSize = 250;

    for (
      var batchStart = 0;
      batchStart < _diveCount;
      batchStart += diveBatchSize
    ) {
      final batchEnd = min(batchStart + diveBatchSize, _diveCount);

      final diveCompanions = <DivesCompanion>[];
      final profileCompanions = <DiveProfilesCompanion>[];
      final tankCompanions = <DiveTanksCompanion>[];
      final diveTagCompanions = <DiveTagsCompanion>[];
      final diveBuddyCompanions = <DiveBuddiesCompanion>[];
      final diveEquipmentCompanions = <DiveEquipmentCompanion>[];
      final sightingCompanions = <SightingsCompanion>[];

      for (var i = batchStart; i < batchEnd; i++) {
        final diveId = _uuid.v4();
        final diveNumber = i + 1;

        // Dive type distribution: 70% rec, 20% advanced, 10% technical
        final typeRoll = _random.nextDouble();
        final String diveType;
        final int durationSeconds;
        final int tankCount;

        if (typeRoll < 0.7) {
          diveType = 'recreational';
          durationSeconds = (30 + _random.nextInt(31)) * 60; // 30-60 min
          tankCount = 1;
        } else if (typeRoll < 0.9) {
          diveType = 'deep';
          durationSeconds = (40 + _random.nextInt(41)) * 60; // 40-80 min
          tankCount = 1 + _random.nextInt(2); // 1-2
        } else {
          diveType = 'technical';
          durationSeconds = (60 + _random.nextInt(121)) * 60; // 60-180 min
          tankCount = 2 + _random.nextInt(3); // 2-4
        }

        // Max depth based on type
        final maxDepth = switch (diveType) {
          'recreational' => 10.0 + _random.nextDouble() * 20, // 10-30m
          'deep' => 25.0 + _random.nextDouble() * 20, // 25-45m
          'technical' => 30.0 + _random.nextDouble() * 60, // 30-90m
          _ => 18.0,
        };

        // Random date over 10 years (use days to stay within nextInt limit)
        final dateOffsetDays = _random.nextInt(tenYearsDays);
        final diveDate = baseDate.subtract(Duration(days: dateOffsetDays));
        final diveDateMs = diveDate.millisecondsSinceEpoch;

        // Site assignment: power-law distribution (first 10% of sites get 50%)
        final siteId = _pickSitePowerLaw(siteIds);

        final avgDepth = maxDepth * 0.6 + _random.nextDouble() * maxDepth * 0.1;
        final waterTemp = 12.0 + _random.nextDouble() * 18; // 12-30 C

        diveCompanions.add(
          DivesCompanion(
            id: Value(diveId),
            diverId: Value(diverId),
            diveNumber: Value(diveNumber),
            diveDateTime: Value(diveDateMs),
            entryTime: Value(diveDateMs),
            exitTime: Value(diveDateMs + durationSeconds * 1000),
            duration: Value(durationSeconds),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            waterTemp: Value(waterTemp),
            airTemp: Value(20.0 + _random.nextDouble() * 15),
            visibility: Value(_pickVisibility()),
            diveType: Value(diveType),
            siteId: Value(siteId),
            rating: Value(_random.nextInt(5) + 1),
            isFavorite: Value(_random.nextDouble() < 0.1),
            diveMode: const Value('oc'),
            cnsStart: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // Profile points (every 2 seconds)
        final points = _buildProfilePoints(diveId, durationSeconds, maxDepth);
        profileCompanions.addAll(points);
        totalProfilePoints += points.length;

        // Tanks
        final tanks = _buildTanks(diveId, tankCount, diveType);
        tankCompanions.addAll(tanks);
        totalTanks += tanks.length;

        // Tags (0-3 per dive)
        final numTags = _random.nextInt(4);
        final shuffledTags = List<String>.from(tagIds)..shuffle(_random);
        for (var t = 0; t < numTags && t < shuffledTags.length; t++) {
          diveTagCompanions.add(
            DiveTagsCompanion(
              id: Value(_uuid.v4()),
              diveId: Value(diveId),
              tagId: Value(shuffledTags[t]),
              createdAt: Value(now),
            ),
          );
        }

        // Buddies (0-2 per dive)
        final numBuddies = _random.nextInt(3);
        final shuffledBuddies = List<String>.from(buddyIds)..shuffle(_random);
        for (var b = 0; b < numBuddies && b < shuffledBuddies.length; b++) {
          diveBuddyCompanions.add(
            DiveBuddiesCompanion(
              id: Value(_uuid.v4()),
              diveId: Value(diveId),
              buddyId: Value(shuffledBuddies[b]),
              role: const Value('buddy'),
              createdAt: Value(now),
            ),
          );
        }

        // Equipment (2-6 per dive)
        final numEquipment = 2 + _random.nextInt(5);
        final shuffledEquip = List<String>.from(equipmentIds)..shuffle(_random);
        for (var e = 0; e < numEquipment && e < shuffledEquip.length; e++) {
          diveEquipmentCompanions.add(
            DiveEquipmentCompanion(
              diveId: Value(diveId),
              equipmentId: Value(shuffledEquip[e]),
            ),
          );
        }

        // Sightings (0-3 per dive)
        if (speciesIds.isNotEmpty) {
          final numSightings = _random.nextInt(4);
          final shuffledSpecies = List<String>.from(speciesIds)
            ..shuffle(_random);
          for (var s = 0; s < numSightings && s < shuffledSpecies.length; s++) {
            sightingCompanions.add(
              SightingsCompanion(
                id: Value(_uuid.v4()),
                diveId: Value(diveId),
                speciesId: Value(shuffledSpecies[s]),
                count: Value(1 + _random.nextInt(5)),
                notes: const Value(''),
              ),
            );
          }
          totalSightings += min(numSightings, shuffledSpecies.length);
        }
      }

      // Insert all data for this batch
      await _batchInsert(_db.dives, diveCompanions);
      await _batchInsert(_db.diveProfiles, profileCompanions, chunkSize: 5000);
      await _batchInsert(_db.diveTanks, tankCompanions);
      if (diveTagCompanions.isNotEmpty) {
        await _batchInsert(_db.diveTags, diveTagCompanions);
      }
      if (diveBuddyCompanions.isNotEmpty) {
        await _batchInsert(_db.diveBuddies, diveBuddyCompanions);
      }
      if (diveEquipmentCompanions.isNotEmpty) {
        await _batchInsert(_db.diveEquipment, diveEquipmentCompanions);
      }
      if (sightingCompanions.isNotEmpty) {
        await _batchInsert(_db.sightings, sightingCompanions);
      }
    }

    return _DiveGenerationStats(
      profilePointCount: totalProfilePoints,
      tankCount: totalTanks,
      sightingCount: totalSightings,
    );
  }

  // --------------------------------------------------------------------------
  // Profile point generation
  // --------------------------------------------------------------------------

  List<DiveProfilesCompanion> _buildProfilePoints(
    String diveId,
    int durationSeconds,
    double maxDepth,
  ) {
    final points = <DiveProfilesCompanion>[];
    const intervalSeconds = 2;

    // Phase durations (as fraction of total time)
    final descentTime = durationSeconds * 0.1;
    final ascentTime = durationSeconds * 0.15;
    final safetyStopStart = durationSeconds * 0.85;
    final safetyStopEnd = durationSeconds * 0.92;

    for (var t = 0; t < durationSeconds; t += intervalSeconds) {
      final double depth;

      if (t < descentTime) {
        // Linear descent
        depth = maxDepth * (t / descentTime);
      } else if (t < safetyStopStart) {
        // Bottom phase (slight variation around max depth)
        depth = maxDepth * (0.9 + _random.nextDouble() * 0.1);
      } else if (t < safetyStopEnd) {
        // Safety stop at 5m
        depth = 5.0 + _random.nextDouble() * 0.5;
      } else {
        // Final ascent from safety stop
        final ascentProgress =
            (t - safetyStopEnd) / (durationSeconds - safetyStopEnd);
        depth = 5.0 * (1.0 - ascentProgress);
      }

      _profilePointCounter++;
      points.add(
        DiveProfilesCompanion(
          id: Value('pp_$_profilePointCounter'),
          diveId: Value(diveId),
          isPrimary: const Value(true),
          timestamp: Value(t),
          depth: Value(depth.clamp(0.0, maxDepth)),
          temperature: Value(12.0 + (t % 80) * 0.1),
        ),
      );
    }

    return points;
  }

  // --------------------------------------------------------------------------
  // Tank generation
  // --------------------------------------------------------------------------

  List<DiveTanksCompanion> _buildTanks(
    String diveId,
    int tankCount,
    String diveType,
  ) {
    final tanks = <DiveTanksCompanion>[];

    for (var i = 0; i < tankCount; i++) {
      final isBackGas = i == 0;
      final o2Percent = isBackGas ? 21.0 : (32.0 + _random.nextInt(20));
      final hePercent = (diveType == 'technical' && !isBackGas)
          ? 10.0 + _random.nextInt(25)
          : 0.0;
      final startPressure = 200 + _random.nextInt(31); // 200-230 bar
      final endPressure = 30 + _random.nextInt(31); // 30-60 bar

      tanks.add(
        DiveTanksCompanion(
          id: Value(_uuid.v4()),
          diveId: Value(diveId),
          volume: const Value(12.0),
          workingPressure: const Value(232),
          startPressure: Value(startPressure),
          endPressure: Value(endPressure),
          o2Percent: Value(o2Percent),
          hePercent: Value(hePercent.toDouble()),
          tankOrder: Value(i),
          tankRole: Value(isBackGas ? 'backGas' : 'deco'),
        ),
      );
    }

    return tanks;
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  /// Power-law site distribution: first 10% of sites receive ~50% of dives.
  String _pickSitePowerLaw(List<String> siteIds) {
    final roll = _random.nextDouble();
    if (roll < 0.5) {
      // Pick from top 10% of sites
      final topCount = max(1, (siteIds.length * 0.1).ceil());
      return siteIds[_random.nextInt(topCount)];
    } else {
      // Pick from remaining 90%
      return siteIds[_random.nextInt(siteIds.length)];
    }
  }

  String _pickVisibility() {
    const options = ['poor', 'fair', 'good', 'excellent'];
    return options[_random.nextInt(options.length)];
  }

  /// Batch insert with chunking to avoid SQLite variable limits.
  Future<void> _batchInsert<T extends Table, D>(
    TableInfo<T, D> table,
    List<Insertable<D>> companions, {
    int chunkSize = 500,
  }) async {
    for (var i = 0; i < companions.length; i += chunkSize) {
      final chunk = companions.sublist(
        i,
        min(i + chunkSize, companions.length),
      );
      await _db.batch((b) => b.insertAll(table, chunk));
    }
  }

  /// Country/region list for realistic geographic distribution.
  List<(String, List<String>)> _buildCountryList() {
    return const [
      (
        'Australia',
        ['Great Barrier Reef', 'Ningaloo Reef', 'Sydney', 'Cairns'],
      ),
      ('Indonesia', ['Bali', 'Raja Ampat', 'Komodo', 'Sulawesi']),
      ('Thailand', ['Similan Islands', 'Koh Tao', 'Phuket', 'Koh Lipe']),
      ('Philippines', ['Cebu', 'Palawan', 'Malapascua', 'Tubbataha']),
      ('Egypt', ['Red Sea', 'Sharm El Sheikh', 'Hurghada', 'Dahab']),
      ('Mexico', ['Cozumel', 'Cancun', 'Cabo Pulmo', 'Socorro']),
      ('Maldives', ['Male Atoll', 'Ari Atoll', 'Baa Atoll', 'Vaavu']),
      ('Honduras', ['Roatan', 'Utila', 'Guanaja']),
      ('Belize', ['Blue Hole', 'Turneffe', 'Ambergris Caye']),
      ('Costa Rica', ['Cocos Island', 'Guanacaste', 'Cahuita']),
      ('Ecuador', ['Galapagos', 'Machalilla']),
      ('Colombia', ['Malpelo', 'San Andres', 'Providencia']),
      ('Malaysia', ['Sipadan', 'Mabul', 'Perhentian']),
      ('Japan', ['Okinawa', 'Izu Peninsula', 'Ogasawara']),
      ('South Africa', ['Sodwana Bay', 'Aliwal Shoal', 'False Bay']),
      ('Mozambique', ['Tofo', 'Bazaruto', 'Inhambane']),
      ('Tanzania', ['Zanzibar', 'Mafia Island', 'Pemba']),
      ('Palau', ['Blue Corner', 'Jellyfish Lake', 'Peleliu']),
      ('Fiji', ['Beqa Lagoon', 'Bligh Water', 'Taveuni']),
      ('Papua New Guinea', ['Kimbe Bay', 'Milne Bay', 'Rabaul']),
      ('Greece', ['Santorini', 'Crete', 'Zakynthos']),
      ('Croatia', ['Vis Island', 'Kornati', 'Dubrovnik']),
      ('Italy', ['Sardinia', 'Ustica', 'Portofino']),
      ('Spain', ['Canary Islands', 'Mallorca', 'Costa Brava']),
      ('Portugal', ['Azores', 'Madeira', 'Algarve']),
      ('Iceland', ['Silfra', 'Strytan']),
      ('Norway', ['Lofoten', 'Trondheim']),
      ('Canada', ['British Columbia', 'Nova Scotia', 'Tobermory']),
      ('USA', ['Hawaii', 'Florida Keys', 'California', 'Puget Sound']),
      ('Cuba', ['Jardines de la Reina', 'Bay of Pigs', 'Maria la Gorda']),
      ('Bahamas', ['Exumas', 'Nassau', 'Tiger Beach']),
      ('Cayman Islands', ['Grand Cayman', 'Little Cayman']),
      ('Bonaire', ['Town Pier', 'Salt Pier', 'Hilma Hooker']),
      ('Curacao', ['Mushroom Forest', 'Tugboat', 'Watamula']),
      ('Aruba', ['Antilla Wreck', 'Mangel Halto']),
      ('Seychelles', ['Mahe', 'Praslin', 'La Digue']),
      ('Mauritius', ['Flic en Flac', 'Trou aux Biches']),
      ('Oman', ['Musandam', 'Daymaniyat Islands']),
      ('UAE', ['Fujairah', 'Dubai']),
      ('Micronesia', ['Chuuk Lagoon', 'Yap', 'Pohnpei']),
    ];
  }
}

/// Internal stats from dive generation.
class _DiveGenerationStats {
  final int profilePointCount;
  final int tankCount;
  final int sightingCount;

  const _DiveGenerationStats({
    required this.profilePointCount,
    required this.tankCount,
    required this.sightingCount,
  });
}
