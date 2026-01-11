import 'dart:math';

import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:uuid/uuid.dart';

/// Seeds the database with realistic test data for App Store screenshots.
///
/// This creates visually appealing data that showcases the app's features:
/// - A diver profile with certifications
/// - Multiple dive sites around the world with GPS coordinates
/// - Varied equipment items
/// - Dives with depth profiles and varied conditions
/// - Buddies for social diving data
class ScreenshotTestDataSeeder {
  final AppDatabase db;
  final _uuid = const Uuid();
  late final String _diverId;

  ScreenshotTestDataSeeder(this.db);

  /// Seeds all test data for screenshots.
  Future<void> seedAll() async {
    _diverId = _uuid.v4();

    await _createDiver();
    await _createDiveSites();
    await _createEquipment();
    await _createBuddies();
    await _createDivesWithProfiles();
  }

  Future<void> _createDiver() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: _diverId,
            name: 'Eric Griffin',
            email: const Value('eric@example.com'),
            phone: const Value('+1 123-456-7890'),
            bloodType: const Value('O+'),
            isDefault: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _createDiveSites() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final sites = [
      // Caribbean
      {
        'name': 'Blue Hole',
        'country': 'Belize',
        'region': 'Lighthouse Reef',
        'lat': 17.3156,
        'lon': -87.5347,
        'maxDepth': 40.0,
        'difficulty': 'Advanced',
        'description':
            'Famous collapsed cave with crystal clear water and stalactites.',
      },
      {
        'name': 'Palancar Gardens',
        'country': 'Mexico',
        'region': 'Cozumel',
        'lat': 20.3579,
        'lon': -87.0386,
        'maxDepth': 25.0,
        'difficulty': 'Beginner',
        'description': 'Beautiful coral formations with abundant marine life.',
      },
      // Red Sea
      {
        'name': 'SS Thistlegorm',
        'country': 'Egypt',
        'region': 'Sharm el-Sheikh',
        'lat': 27.8142,
        'lon': 33.9208,
        'maxDepth': 32.0,
        'difficulty': 'Intermediate',
        'description':
            'WWII shipwreck with motorcycles, trucks, and locomotives.',
      },
      {
        'name': 'Ras Mohammed',
        'country': 'Egypt',
        'region': 'Sharm el-Sheikh',
        'lat': 27.7333,
        'lon': 34.2500,
        'maxDepth': 40.0,
        'difficulty': 'Intermediate',
        'description': 'Spectacular walls and shark reef at the tip of Sinai.',
      },
      // Southeast Asia
      {
        'name': 'USAT Liberty Wreck',
        'country': 'Indonesia',
        'region': 'Tulamben, Bali',
        'lat': -8.2750,
        'lon': 115.5944,
        'maxDepth': 30.0,
        'difficulty': 'Beginner',
        'description': 'Shore-accessible WWII cargo ship covered in coral.',
      },
      {
        'name': 'Richelieu Rock',
        'country': 'Thailand',
        'region': 'Similan Islands',
        'lat': 9.3617,
        'lon': 98.0250,
        'maxDepth': 35.0,
        'difficulty': 'Advanced',
        'description': 'Famous for whale shark and manta ray encounters.',
      },
      {
        'name': 'Barracuda Point',
        'country': 'Malaysia',
        'region': 'Sipadan',
        'lat': 4.1147,
        'lon': 118.6289,
        'maxDepth': 40.0,
        'difficulty': 'Advanced',
        'description': 'Massive schools of barracuda forming tornado spirals.',
      },
      // Pacific
      {
        'name': 'Blue Corner',
        'country': 'Palau',
        'region': 'Koror',
        'lat': 7.1333,
        'lon': 134.2167,
        'maxDepth': 35.0,
        'difficulty': 'Advanced',
        'description': 'World-famous wall dive with sharks and large pelagics.',
      },
      {
        'name': 'SS Yongala',
        'country': 'Australia',
        'region': 'Queensland',
        'lat': -19.3056,
        'lon': 147.6222,
        'maxDepth': 30.0,
        'difficulty': 'Intermediate',
        'description':
            'Historic passenger liner with incredible marine life diversity.',
      },
      // Mediterranean
      {
        'name': 'MV Zenobia',
        'country': 'Cyprus',
        'region': 'Larnaca',
        'lat': 34.8833,
        'lon': 33.6500,
        'maxDepth': 42.0,
        'difficulty': 'Intermediate',
        'description': 'Swedish ferry with 104 trucks on board, sunk in 1980.',
      },
      // Americas
      {
        'name': 'Cenote Dos Ojos',
        'country': 'Mexico',
        'region': 'Quintana Roo',
        'lat': 20.3244,
        'lon': -87.3914,
        'maxDepth': 10.0,
        'difficulty': 'Beginner',
        'description':
            'Crystal clear cenote with stunning light beams and formations.',
      },
      {
        'name': 'Monterey Breakwater',
        'country': 'USA',
        'region': 'California',
        'lat': 36.6167,
        'lon': -121.9000,
        'maxDepth': 20.0,
        'difficulty': 'Beginner',
        'description': 'Kelp forests with seals, nudibranchs, and octopus.',
      },
    ];

    for (final site in sites) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: _uuid.v4(),
              diverId: Value(_diverId),
              name: site['name'] as String,
              description: Value(site['description'] as String),
              latitude: Value(site['lat'] as double),
              longitude: Value(site['lon'] as double),
              maxDepth: Value(site['maxDepth'] as double),
              difficulty: Value(site['difficulty'] as String),
              country: Value(site['country'] as String),
              region: Value(site['region'] as String),
              rating: Value(4.0 + Random().nextDouble()),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _createEquipment() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sixMonthsAgo = now - (180 * 24 * 60 * 60 * 1000); // 180 days in ms

    final equipment = [
      {
        'name': 'Primary Regulator',
        'type': 'regulator',
        'brand': 'Apeks',
        'model': 'XTX 200',
        'status': 'active',
        'serviceInterval': 365,
      },
      {
        'name': 'BCD',
        'type': 'bcd',
        'brand': 'ScubaPro',
        'model': 'Hydros Pro',
        'status': 'active',
        'serviceInterval': 365,
      },
      {
        'name': 'Dive Computer',
        'type': 'computer',
        'brand': 'Shearwater',
        'model': 'Perdix 2',
        'status': 'active',
        'serviceInterval': null,
      },
      {
        'name': '5mm Wetsuit',
        'type': 'wetsuit',
        'brand': 'Fourth Element',
        'model': 'Xenos',
        'status': 'active',
        'serviceInterval': null,
      },
      {
        'name': 'Mask',
        'type': 'mask',
        'brand': 'Atomic',
        'model': 'Venom',
        'status': 'active',
        'serviceInterval': null,
      },
      {
        'name': 'Fins',
        'type': 'fins',
        'brand': 'Mares',
        'model': 'Avanti Quattro+',
        'status': 'active',
        'serviceInterval': null,
      },
      {
        'name': 'Dive Light',
        'type': 'light',
        'brand': 'Big Blue',
        'model': 'VL4200P',
        'status': 'active',
        'serviceInterval': null,
      },
      {
        'name': 'SMB',
        'type': 'safety',
        'brand': 'Halcyon',
        'model': 'Diver Alert Marker',
        'status': 'active',
        'serviceInterval': null,
      },
      {
        'name': 'AL80 Tank',
        'type': 'tank',
        'brand': 'Luxfer',
        'model': 'AL80',
        'status': 'active',
        'serviceInterval': 365,
      },
      {
        'name': 'Backup Regulator',
        'type': 'regulator',
        'brand': 'Apeks',
        'model': 'XL4+',
        'status': 'needsService',
        'serviceInterval': 365,
      },
    ];

    for (final item in equipment) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: _uuid.v4(),
              diverId: Value(_diverId),
              name: item['name'] as String,
              type: item['type'] as String,
              brand: Value(item['brand'] as String),
              model: Value(item['model'] as String),
              status: Value(item['status'] as String),
              lastServiceDate: Value(sixMonthsAgo),
              serviceIntervalDays: item['serviceInterval'] != null
                  ? Value(item['serviceInterval'] as int)
                  : const Value.absent(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _createBuddies() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final buddies = [
      {
        'name': 'Sarah Chen',
        'email': 'sarah.chen@email.com',
        'certLevel': 'PADI Rescue Diver',
        'agency': 'PADI',
      },
      {
        'name': 'Marcus Johnson',
        'email': 'marcus.j@email.com',
        'certLevel': 'SSI Advanced Open Water',
        'agency': 'SSI',
      },
      {
        'name': 'Elena Rodriguez',
        'email': 'elena.r@email.com',
        'certLevel': 'PADI Divemaster',
        'agency': 'PADI',
      },
      {
        'name': 'James Wilson',
        'email': 'jwilson@email.com',
        'certLevel': 'NAUI Open Water',
        'agency': 'NAUI',
      },
      {
        'name': 'Yuki Tanaka',
        'email': 'yuki.t@email.com',
        'certLevel': 'TDI Advanced Nitrox',
        'agency': 'TDI',
      },
    ];

    for (final buddy in buddies) {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: _uuid.v4(),
              diverId: Value(_diverId),
              name: buddy['name'] as String,
              email: Value(buddy['email'] as String),
              certificationLevel: Value(buddy['certLevel'] as String),
              certificationAgency: Value(buddy['agency'] as String),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _createDivesWithProfiles() async {
    final now = DateTime.now();
    final random = Random(42); // Fixed seed for reproducible data

    // Get all sites for random assignment
    final sites = await db.select(db.diveSites).get();

    // Create 75 dives spread over the past 2 years
    for (var i = 0; i < 75; i++) {
      final daysAgo = random.nextInt(730); // Up to 2 years
      final diveDate = now.subtract(Duration(days: daysAgo));
      final diveTimestamp = diveDate.millisecondsSinceEpoch; // milliseconds!

      // Varied dive parameters
      final maxDepth = 12.0 + random.nextDouble() * 30; // 12-42m
      final avgDepth = maxDepth * (0.5 + random.nextDouble() * 0.2);
      final durationSeconds = 35 + random.nextInt(30); // 35-65 min
      final durationMs = durationSeconds * 60 * 1000; // convert to milliseconds
      final waterTemp = 18.0 + random.nextDouble() * 10; // 18-28C

      final visibility = [
        'poor',
        'moderate',
        'good',
        'excellent',
      ][random.nextInt(4)];
      final diveTypes = [
        'recreational',
        'reef',
        'wreck',
        'drift',
        'night',
        'deep',
      ];
      final diveType = diveTypes[random.nextInt(diveTypes.length)];

      final site = sites[random.nextInt(sites.length)];
      final rating = 3 + random.nextInt(3); // 3-5 stars

      final diveId = _uuid.v4();

      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: diveId,
              diverId: Value(_diverId),
              diveNumber: Value(75 - i), // Number dives in reverse
              diveDateTime: diveTimestamp,
              entryTime: Value(diveTimestamp),
              exitTime: Value(
                diveTimestamp + durationMs,
              ), // exit = entry + duration
              duration: Value(durationSeconds * 60), // duration in seconds
              maxDepth: Value(maxDepth),
              avgDepth: Value(avgDepth),
              waterTemp: Value(waterTemp),
              visibility: Value(visibility),
              diveType: Value(diveType),
              siteId: Value(site.id),
              rating: Value(rating),
              notes: Value(_generateDiveNotes(diveType, site.name)),
              createdAt: diveTimestamp,
              updatedAt: diveTimestamp,
            ),
          );

      // Create tank entry
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: _uuid.v4(),
              diveId: diveId,
              volume: const Value(11.1),
              workingPressure: const Value(207),
              startPressure: Value(200 + random.nextInt(10)),
              endPressure: Value(40 + random.nextInt(30)),
              o2Percent: const Value(21.0),
            ),
          );

      // Create depth profile with realistic dive shape
      await _createDiveProfile(
        diveId,
        durationSeconds * 60, // duration in seconds for profile
        maxDepth,
        waterTemp + random.nextDouble() * 2,
      );
    }
  }

  Future<void> _createDiveProfile(
    String diveId,
    int duration,
    double maxDepth,
    double temp,
  ) async {
    final random = Random();

    // Create profile points every 10 seconds
    final numPoints = duration ~/ 10;

    for (var i = 0; i < numPoints; i++) {
      final timestamp = i * 10;
      final progress = timestamp / duration;

      // Realistic depth profile: descent, bottom time, gradual ascent
      double depth;
      if (progress < 0.08) {
        // Descent phase (8% of dive)
        depth = maxDepth * (progress / 0.08);
      } else if (progress < 0.75) {
        // Bottom time with variation (67% of dive)
        final bottomProgress = (progress - 0.08) / 0.67;
        depth = maxDepth * (0.85 + 0.15 * sin(bottomProgress * 6));
        depth += (random.nextDouble() - 0.5) * 2; // Small random variation
      } else if (progress < 0.92) {
        // Main ascent (17% of dive)
        final ascentProgress = (progress - 0.75) / 0.17;
        depth = maxDepth * (1 - ascentProgress) * 0.85;
        // Add safety stop bump at 5m
        if (depth < 6 && depth > 4) {
          depth = 5.0;
        }
      } else {
        // Safety stop and final ascent (8% of dive)
        final finalProgress = (progress - 0.92) / 0.08;
        depth = 5.0 * (1 - finalProgress);
      }

      depth = depth.clamp(0.0, maxDepth);

      // Realistic pressure consumption: faster at depth due to ambient pressure
      // SAC rate increases with depth (Boyle's Law effect)
      final depthFactor = 1 + (depth / 10); // More consumption at depth
      final baseConsumption = (timestamp / duration) * 150;
      final depthAdjustedConsumption =
          baseConsumption * (0.7 + 0.3 * depthFactor);
      // Add small random variation to simulate breathing patterns
      final breathingVariation = (random.nextDouble() - 0.5) * 2;
      final pressure = (200 - depthAdjustedConsumption + breathingVariation)
          .clamp(40.0, 210.0);

      await db
          .into(db.diveProfiles)
          .insert(
            DiveProfilesCompanion.insert(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: depth,
              temperature: Value(
                temp - (depth * 0.1),
              ), // Temp decreases with depth
              pressure: Value(pressure), // Realistic gas consumption
            ),
          );
    }
  }

  String _generateDiveNotes(String diveType, String siteName) {
    final notes = {
      'recreational': 'Great visibility today. Saw plenty of reef fish.',
      'reef': 'Beautiful coral formations. Spotted a sea turtle!',
      'wreck': 'Explored the main deck and cargo holds. Amazing penetration.',
      'drift': 'Strong current made for an exciting ride along the wall.',
      'night': 'Incredible bioluminescence. Found several sleeping parrotfish.',
      'deep': 'Reached target depth. Narcosis was manageable.',
    };
    return notes[diveType] ?? 'Great dive at $siteName!';
  }
}
