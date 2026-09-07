import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/macdive_samples_decoder.dart';
import 'package:submersion/features/universal_import/data/services/macdive_unit_inference.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  late Uint8List bytes;

  setUpAll(() async {
    final path =
        '${Directory.systemTemp.path}/mdm_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final file = buildSyntheticMacDiveDb(path);
    bytes = Uint8List.fromList(await file.readAsBytes());
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
  });

  group('MacDiveDiveMapper', () {
    test('produces 3 dives, 2 sites, 2 buddies, 2 tags, 2 gear', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 2);
      expect(payload.entitiesOf(ImportEntityType.buddies).length, 2);
      expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
      expect(payload.entitiesOf(ImportEntityType.equipment).length, 2);
    });

    test('maps MacDive dive types onto Submersion type ids', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);

      // "Shore" slugs onto the built-in id; "Aquarium" is carried across as
      // a custom type (#912).
      final types = payload.entitiesOf(ImportEntityType.diveTypes);
      expect(types.map((t) => t['id']), containsAll(['shore', 'aquarium']));
      expect(
        types.firstWhere((t) => t['id'] == 'aquarium')['name'],
        'Aquarium',
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final dive1 = dives.firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      expect(dive1['diveTypeIds'], containsAll(['shore', 'aquarium']));
      final dive3 = dives.firstWhere((d) => d['sourceUuid'] == 'dive-uuid-3');
      expect(dive3.containsKey('diveTypeIds'), isFalse);
    });

    test('operator becomes a dive center and a per-dive ref', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);

      final centers = payload.entitiesOf(ImportEntityType.diveCenters);
      // Two dives share one operator, so it is deduplicated.
      expect(centers, hasLength(1));
      expect(centers.single['name'], 'Test Operator');
      expect(centers.single['uddfId'], 'Test Operator');
      expect(centers.single['country'], 'Mexico');

      final dive1 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      expect(dive1['diveCenterRef'], 'Test Operator');
      // The free-text column keeps its value too.
      expect(dive1['diveOperator'], 'Test Operator');
    });

    test('inactive MacDive gear imports as retired', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final gear = payload.entitiesOf(ImportEntityType.equipment);

      final active = gear.firstWhere((g) => g['name'] == 'Hydros Pro');
      expect(active.containsKey('status'), isFalse);
      expect(active.containsKey('isActive'), isFalse);

      final retired = gear.firstWhere((g) => g['name'] == 'Old Regs');
      expect(retired['status'], 'retired');
      // Both markers are needed: getActiveEquipment filters on each.
      expect(retired['isActive'], isFalse);
    });

    test('gear type strings map onto EquipmentType', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final gear = payload.entitiesOf(ImportEntityType.equipment);

      // "BCD - Wing" and "Reg - Longhose" match no enum name; without the
      // value mapper both would land as `other`.
      expect(gear.firstWhere((g) => g['name'] == 'Hydros Pro')['type'], 'bcd');
      expect(
        gear.firstWhere((g) => g['name'] == 'Old Regs')['type'],
        'regulator',
      );
    });

    test('gear price uses the key the importer reads', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final active = payload
          .entitiesOf(ImportEntityType.equipment)
          .firstWhere((g) => g['name'] == 'Hydros Pro');
      // `price` was silently dropped; `_importEquipment` reads purchasePrice.
      expect(active['purchasePrice'], 499.0);
      expect(active['purchaseCurrency'], 'USD');
      expect(active.containsKey('price'), isFalse);
    });

    test('certifications reach the payload', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final cert = payload.entitiesOf(ImportEntityType.certifications).single;
      expect(cert['name'], 'Rescue Scuba Diver');
      expect(cert['agency'], 'NAUI');
      expect(cert['cardNumber'], '2649227');
      expect(cert['instructorName'], 'Jose Salazar');
      expect(cert['issueDate'], isA<DateTime>());
      expect(cert['notes'], contains('Bamboo Reef'));
    });

    test('service records reference their gear by uddfId', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final record = payload.entitiesOf(ImportEntityType.serviceRecords).single;
      // Must match the equipment entity's uddfId so the importer can resolve
      // it through equipmentIdMapping.
      final gear = payload
          .entitiesOf(ImportEntityType.equipment)
          .firstWhere((g) => g['name'] == 'Hydros Pro');
      expect(record['equipmentRef'], gear['uddfId']);
      expect(record['provider'], 'Seals Watersports');
      expect(record['serviceDate'], isA<DateTime>());
    });

    test('a service record with no date is dropped, not carried', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(
        MacDiveRawLogbook(
          dives: logbook.dives,
          sitesByPk: logbook.sitesByPk,
          buddiesByPk: logbook.buddiesByPk,
          tagsByPk: logbook.tagsByPk,
          gearByPk: logbook.gearByPk,
          tanksByPk: logbook.tanksByPk,
          gasesByPk: logbook.gasesByPk,
          tankAndGases: logbook.tankAndGases,
          crittersByPk: logbook.crittersByPk,
          certifications: logbook.certifications,
          serviceRecords: [
            MacDiveRawServiceRecord(
              pk: 99,
              uuid: 'no-date',
              gearFk: logbook.gearByPk.keys.first,
              servicedBy: 'Someone',
            ),
          ],
          events: logbook.events,
          diveToBuddyPks: logbook.diveToBuddyPks,
          diveToTagPks: logbook.diveToTagPks,
          diveToGearPks: logbook.diveToGearPks,
          diveToCritterPks: logbook.diveToCritterPks,
          unitsPreference: logbook.unitsPreference,
        ),
      );

      // The importer requires a service date, so emitting a dateless record
      // would only inflate the count shown in the review step.
      expect(payload.entitiesOf(ImportEntityType.serviceRecords), isEmpty);
    });

    test('a multi-diver library is flagged and tagged by diver', () async {
      final payload = await MacDiveDiveMapper.toPayload(_multiDiverLogbook());

      // #912: several MacDive divers used to merge into one flat list with
      // no way to tell them apart.
      final warning = payload.warnings.singleWhere(
        (w) => w.message.contains('2 divers'),
      );
      expect(warning.severity, ImportWarningSeverity.warning);
      expect(warning.message, contains('Ann Lee'));
      expect(warning.message, contains('Bo Ray'));

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.firstWhere((d) => d['sourceUuid'] == 'dive-1')['tagRefs'], [
        'Ann Lee',
      ]);
      expect(dives.firstWhere((d) => d['sourceUuid'] == 'dive-2')['tagRefs'], [
        'Bo Ray',
      ]);
      // A dive with no diver link gets no diver tag.
      expect(
        dives
            .firstWhere((d) => d['sourceUuid'] == 'dive-3')
            .containsKey('tagRefs'),
        isFalse,
      );

      // The names are also emitted as tag entities so the refs resolve.
      expect(
        payload.entitiesOf(ImportEntityType.tags).map((t) => t['name']),
        containsAll(['Ann Lee', 'Bo Ray']),
      );
    });

    test('a single-diver library is not tagged or flagged', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        _multiDiverLogbook(singleDiver: true),
      );
      expect(
        payload.warnings.where((w) => w.message.contains('divers')),
        isEmpty,
      );
      expect(payload.entitiesOf(ImportEntityType.tags), isEmpty);
      for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
        expect(dive.containsKey('tagRefs'), isFalse);
      }
    });

    test('MacDive logbooks are reported as not imported', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final warning = payload.warnings.singleWhere(
        (w) => w.message.contains('Tropical'),
      );
      expect(warning.severity, ImportWarningSeverity.info);
      expect(warning.message, contains('saved searches'));
    });

    test('dive sourceUuid preserved', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final uuids = dives.map((d) => d['sourceUuid']).toSet();
      expect(uuids, {'dive-uuid-1', 'dive-uuid-2', 'dive-uuid-3'});
    });

    test(
      'dive 1 has tagRefs [Reef, Photography] and buddies [Alice, Bob]',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = await MacDiveDiveMapper.toPayload(logbook);
        final dive1 = payload
            .entitiesOf(ImportEntityType.dives)
            .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
        expect(dive1['tagRefs'], containsAll(['Reef', 'Photography']));
        expect(dive1['unmatchedBuddyNames'], containsAll(['Alice', 'Bob']));
      },
    );

    test('dive 3 has no buddies or tags', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dive3 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-3');
      expect(dive3['tagRefs'], anyOf(isNull, isEmpty));
      expect(dive3['unmatchedBuddyNames'], anyOf(isNull, isEmpty));
    });

    test('dive 1 tanks include gas mix and pressures', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dive1 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      final tanks = dive1['tanks'] as List?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 1);
      final tank = tanks.first as Map<String, dynamic>;
      // Synthetic: AL80 + EAN32 + 3000 psi start / 1000 psi end.
      // Units preference is Metric in the fixture, so raw values
      // pass through as-is (3000 "bar", 1000 "bar") because the
      // Metric branch is a passthrough. This is intentional -
      // the synthetic fixture isn't testing unit conversion, the
      // unit-converter tests in M2 did that.
      expect(tank['startPressure'], 3000);
      expect(tank['endPressure'], 1000);
      // #517: volume and working pressure must use the same payload keys the
      // shared UddfEntityImporter._buildTanks reads (`volume` /
      // `workingPressure`), NOT `volumeL` / `workingPressureBar`. A mismatched
      // key silently drops the value, which zeroes out volume-based SAC
      // statistics even though the per-dive SAC (which has a volume fallback)
      // still renders.
      expect(tank['volume'], isNotNull);
      expect(tank['volume'] as num, greaterThan(0));
      expect(tank['workingPressure'], isNotNull);
      expect(tank['workingPressure'] as num, greaterThan(0));
      expect(tank.containsKey('volumeL'), isFalse);
      expect(tank.containsKey('workingPressureBar'), isFalse);
      // gasMix must be a `GasMix` object, not a Map — UddfEntityImporter does
      // `t['gasMix'] as GasMix?` and a Map cast would throw at runtime.
      // MacDive stores oxygen as a whole percent (32.0), matching GasMix.o2.
      expect(tank['gasMix'], isA<GasMix>());
      final gasMix = tank['gasMix'] as GasMix;
      expect(gasMix.o2, closeTo(32.0, 0.01));
      expect(gasMix.he, closeTo(0.0, 0.01));
    });

    test('sites: saltwater/freshwater mapped to enum names', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final sites = payload.entitiesOf(ImportEntityType.sites);
      final salt = sites.firstWhere((s) => s['name'] == 'Test Reef');
      final fresh = sites.firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(
        salt['waterType'],
        'salt',
        reason: 'MacDive "saltwater" -> WaterType.salt.name',
      );
      expect(fresh['waterType'], 'fresh');
    });

    test('sites: lat=0 lon=0 filtered to null', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final fresh = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(fresh.containsKey('latitude'), isFalse);
      expect(fresh.containsKey('longitude'), isFalse);
    });

    test('no profile key when a dive has no ZRAWDATA', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      // The synthetic fixture carries no raw blobs, so the key stays absent -
      // matching macdive_xml_parser.dart's convention of omitting it when no
      // samples are available.
      for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
        expect(dive.containsKey('profile'), isFalse);
      }
      // The only warning is about the smart logbook, not about profiles.
      expect(
        payload.warnings.where((w) => w.message.contains('profile')),
        isEmpty,
      );
    });

    test('ZRAWDATA is decompressed and parsed into profile samples', () async {
      final calls = <(String, String, int)>[];
      final payload = await MacDiveDiveMapper.toPayload(
        _rawDataLogbook(),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (vendor, product, model, data) async {
          calls.add((vendor, product, data.length));
          return _parsedDive(
            samples: [
              pigeon.ProfileSample(
                timeSeconds: 0,
                depthMeters: 0.0,
                temperatureCelsius: 25.0,
                pressureBar: 200.0,
              ),
              pigeon.ProfileSample(
                timeSeconds: 10,
                depthMeters: 5.5,
                temperatureCelsius: 24.0,
                pressureBar: 198.0,
              ),
            ],
          );
        },
      );

      // Both Shearwater dives reached the parser; the manual dive did not.
      expect(calls, hasLength(2));
      expect(calls.first.$1, 'Shearwater');
      expect(calls.first.$2, 'Teric');
      // The raw blob was decompressed before parsing, not passed through.
      expect(calls.first.$3, isNot(_compressedFixture.length));

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withProfile = dives.where((d) => d.containsKey('profile')).toList();
      expect(withProfile, hasLength(2));

      final profile = withProfile.first['profile'] as List;
      expect(profile, hasLength(2));
      expect(profile[1]['depth'], 5.5);
      expect(profile[1]['temperature'], 24.0);
      expect(profile[1]['allTankPressures'], [
        {'pressure': 198.0, 'tankIndex': 0},
      ]);
      expect(payload.warnings, isEmpty);
    });

    test(
      'Suunto EON Steel Black ZRAWDATA is passed through unmodified',
      () async {
        final calls = <(String, String, Uint8List)>[];
        final payload = await MacDiveDiveMapper.toPayload(
          _suuntoRawDataLogbook(
            computer: 'Suunto EON Steel Black',
            raw: _suuntoFixture,
          ),
          fetchDescriptors: _fakeDescriptors,
          parseRaw: (vendor, product, model, data) async {
            calls.add((vendor, product, data));
            return _parsedDive(
              samples: [
                pigeon.ProfileSample(
                  timeSeconds: 0,
                  depthMeters: 1.2,
                  temperatureCelsius: 22.0,
                  pressureBar: 190.0,
                ),
              ],
            );
          },
        );

        expect(calls, hasLength(1));
        expect(calls.single.$1, 'Suunto');
        expect(calls.single.$2, 'EON Steel Black');
        // Unlike Shearwater, the bytes reach the parser exactly as MacDive
        // stored them - no decompression pass. Compared byte for byte, not by
        // length, because the XOR-delta half of the Shearwater decompressor
        // rewrites a buffer in place without changing its size.
        expect(calls.single.$3, orderedEquals(_suuntoFixture));

        final dives = payload.entitiesOf(ImportEntityType.dives);
        expect(dives.where((d) => d.containsKey('profile')), hasLength(1));
        expect(payload.warnings, isEmpty);
      },
    );

    test(
      'any libdivecomputer-supported model resolves, not an allowlist',
      () async {
        // Before #1436 only three Suunto models were decodable, because they
        // were the three someone happened to have data for. Every model
        // libdivecomputer knows must now reach the parser; the D5 and Zoop
        // Novo were on the warning path with their bytes sitting unread.
        final calls = <(String, String, int)>[];
        Future<pigeon.ParsedDive> parse(
          String vendor,
          String product,
          int model,
          Uint8List data,
        ) async {
          calls.add((vendor, product, model));
          return _parsedDive(
            samples: [
              pigeon.ProfileSample(
                timeSeconds: 0,
                depthMeters: 3.0,
                temperatureCelsius: 20.0,
                pressureBar: 180.0,
              ),
            ],
          );
        }

        for (final computer in [
          'Suunto EON Steel',
          'Suunto Cobra',
          'Suunto D5',
          'Mares Puck 4',
        ]) {
          final payload = await MacDiveDiveMapper.toPayload(
            _suuntoRawDataLogbook(computer: computer, raw: _suuntoFixture),
            fetchDescriptors: _fakeDescriptors,
            parseRaw: parse,
          );
          expect(
            payload.warnings,
            isEmpty,
            reason: '$computer should decode without a warning',
          );
        }

        // The model number now comes from the descriptor rather than being
        // left as 0 for find_descriptor to wildcard-match.
        expect(calls, [
          ('Suunto', 'EON Steel', 0x00),
          ('Suunto', 'Cobra', 0x0C),
          ('Suunto', 'D5', 0x02),
          ('Mares', 'Puck 4', 0x35),
        ]);
      },
    );

    test('a spacing variant still resolves to the descriptor name', () async {
      // Source apps spell products without the space libdivecomputer uses.
      final calls = <(String, String)>[];
      await MacDiveDiveMapper.toPayload(
        _suuntoRawDataLogbook(computer: 'Mares Puck4', raw: _suuntoFixture),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (vendor, product, model, data) async {
          calls.add((vendor, product));
          return _parsedDive(
            samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 3.0)],
          );
        },
      );
      expect(calls, [('Mares', 'Puck 4')]);
    });

    test('every model of an ambiguous product name is tried', () async {
      // libdivecomputer declares (Suunto, Zoop Novo) twice, 0x1E and 0x1F.
      // The parser is the same either way, but the model number reaches it,
      // so a first-match-wins rule would silently pick a header layout.
      final models = <int>[];
      final payload = await MacDiveDiveMapper.toPayload(
        _suuntoRawDataLogbook(
          computer: 'Suunto Zoop Novo',
          raw: _suuntoFixture,
        ),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (vendor, product, model, data) async {
          models.add(model);
          // 0x1E produces a dive no one has ever made; only 0x1F is real.
          return model == 0x1E
              ? _parsedDive(
                  samples: [
                    pigeon.ProfileSample(timeSeconds: 0, depthMeters: 4000.0),
                  ],
                )
              : _parsedDive(
                  samples: [
                    pigeon.ProfileSample(timeSeconds: 0, depthMeters: 12.0),
                  ],
                );
        },
      );

      expect(models, [0x1E, 0x1F]);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.single.containsKey('profile'), isTrue);
      expect(payload.warnings, isEmpty);
    });

    test('a parser error on one model falls through to the next', () async {
      // libdivecomputer rejecting one model of an ambiguous name is a normal
      // result, not a reason to give up on the dive.
      final models = <int>[];
      final payload = await MacDiveDiveMapper.toPayload(
        _suuntoRawDataLogbook(
          computer: 'Suunto Zoop Novo',
          raw: _suuntoFixture,
        ),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (vendor, product, model, data) async {
          models.add(model);
          if (model == 0x1E) {
            throw PlatformException(code: 'PARSE_ERROR', message: 'bad header');
          }
          return _parsedDive(
            samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 12.0)],
          );
        },
      );

      expect(models, [0x1E, 0x1F]);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.single.containsKey('profile'), isTrue);
      expect(payload.warnings, isEmpty);
    });

    test('an unsupported-platform error stops the whole import', () async {
      // Unlike a parse error, this says the channel itself cannot serve us, so
      // trying the next model - or the next dive - cannot help.
      var calls = 0;
      final payload = await MacDiveDiveMapper.toPayload(
        _rawDataLogbook(),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (v, p, m, d) async {
          calls++;
          throw PlatformException(code: 'UNSUPPORTED', message: 'no parser');
        },
      );

      expect(calls, 1, reason: 'must not retry once the channel is out');
      expect(payload.warnings, hasLength(1));
      expect(payload.warnings.single.message, contains('this platform'));
    });

    test('an implausible parse is rejected rather than attached', () async {
      // Dropping the allowlist means the parser is now offered bytes it may
      // not own. A structurally valid series that no dive could produce must
      // not become a profile.
      final payload = await MacDiveDiveMapper.toPayload(
        _suuntoRawDataLogbook(computer: 'Suunto D5', raw: _suuntoFixture),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (v, p, m, d) async => _parsedDive(
          samples: [
            pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
            pigeon.ProfileSample(timeSeconds: 600, depthMeters: 4000.0),
          ],
        ),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.single.containsKey('profile'), isFalse);
      expect(payload.warnings, hasLength(1));
      expect(payload.warnings.single.message.toLowerCase(), contains('xml'));
    });

    test(
      'unrecognised computer counts toward one aggregated warning',
      () async {
        // A real MacDive value: "Oceanic" is a libdivecomputer vendor but
        // "Matrix Master" is not one of its products, so resolution has to
        // fail closed rather than settle for the vendor.
        final payload = await MacDiveDiveMapper.toPayload(
          _rawDataLogbook(computer: 'Oceanic Matrix Master'),
          fetchDescriptors: _fakeDescriptors,
          parseRaw: (v, p, m, d) async =>
              fail('parser must not be reached for an unknown model'),
        );

        expect(payload.warnings, hasLength(1));
        final w = payload.warnings.single;
        expect(w.severity, ImportWarningSeverity.info);
        expect(w.entityType, ImportEntityType.dives);
        expect(w.message, contains('2 dive'));
        expect(w.message.toLowerCase(), contains('xml'));
      },
    );

    test('missing platform channel warns once, not once per dive', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        _rawDataLogbook(),
        fetchDescriptors: _fakeDescriptors,
        parseRaw: (v, p, m, d) async =>
            throw MissingPluginException('no channel'),
      );

      expect(payload.warnings, hasLength(1));
      expect(payload.warnings.single.message, contains('this platform'));
    });

    test('an unreadable descriptor list warns about the platform', () async {
      // libdivecomputer always knows some computers, so an empty or failing
      // descriptor call means the native side could not answer. Reporting
      // that as "every one of your dives is undecodable" would be wrong.
      for (final fetch in <MacDiveDescriptorFetchFn>[
        () async => throw MissingPluginException('no channel'),
        () async => throw PlatformException(code: 'UNSUPPORTED'),
        () async => throw StateError('something else entirely'),
        () async => [],
      ]) {
        final payload = await MacDiveDiveMapper.toPayload(
          _rawDataLogbook(),
          fetchDescriptors: fetch,
          parseRaw: (v, p, m, d) async =>
              fail('parser must not be reached without descriptors'),
        );
        expect(payload.warnings, hasLength(1));
        expect(payload.warnings.single.message, contains('this platform'));
      }
    });

    test('the descriptor list is read once per import, not per dive', () async {
      var fetches = 0;
      await MacDiveDiveMapper.toPayload(
        _rawDataLogbook(),
        fetchDescriptors: () async {
          fetches++;
          return _fakeDescriptors();
        },
        parseRaw: (v, p, m, d) async => _parsedDive(
          samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 3.0)],
        ),
      );
      expect(fetches, 1);
    });

    test('a logbook with no raw bytes never asks for descriptors', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      await MacDiveDiveMapper.toPayload(
        logbook,
        fetchDescriptors: () async =>
            fail('descriptors must not be fetched with nothing to decode'),
      );
    });

    // #1606: `ZSURFACEINTERVAL` holds minutes. Confirmed by joining a real
    // MacDive.sqlite against the XML export of the same logbook: the column
    // and `<surfaceInterval>` carry the identical number for all 381
    // dives present in both, and MacDive's UDDF export of that number is
    // `value * 60` seconds.
    group('ZSURFACEINTERVAL', () {
      test('maps to minutes, not seconds', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _surfaceIntervalLogbook(138),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive['surfaceInterval'], const Duration(minutes: 138));
      });

      test('zero is omitted (MacDive uses it for no prior dive)', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _surfaceIntervalLogbook(0),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive.containsKey('surfaceInterval'), isFalse);
      });

      test('a fraction of a minute rounds away rather than to 0m', () async {
        // The column is a float. Guarding on the raw value before rounding
        // let anything under half a minute through as Duration.zero, which
        // is the 0m interval this field is meant to never produce.
        final payload = await MacDiveDiveMapper.toPayload(
          _surfaceIntervalLogbook(0.4),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive.containsKey('surfaceInterval'), isFalse);
      });
    });

    group('ZSAMPLES', () {
      test('a dive with only ZSAMPLES gets its profile from them', () async {
        // The 83 "(no computer)" dives of the reference library, and every
        // dive from a computer MacDive did not download through
        // libdivecomputer: no raw bytes, only MacDive's own samples.
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Oceanic Matrix Master',
            samples: _zsamples([
              (0.0, 0.0, 3000.0, 99, 0.21, 27.5, 0),
              (10.0, 5.5, 2980.0, 60, 0.32, 26.0, 1),
            ]),
            unitsPreference: 'Imperial',
          ),
          fetchDescriptors: () async =>
              fail('nothing to resolve without raw bytes'),
        );

        expect(payload.warnings, isEmpty);
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        final profile = dive['profile'] as List;
        expect(profile, hasLength(2));
        final point = profile[1] as Map<String, dynamic>;
        expect(point['timestamp'], 10);
        expect(point['depth'], closeTo(5.5, 1e-6));
        expect(point['temperature'], closeTo(26.0, 1e-6));
        // Sample pressures follow the display unit like the tank columns do:
        // 2980 psi, not 2980 bar (#912 all over again otherwise).
        final pressures = point['allTankPressures'] as List;
        expect(pressures, hasLength(1));
        expect(
          (pressures.single as Map)['pressure'],
          closeTo(2980 * 0.0689476, 1e-3),
        );
        expect((pressures.single as Map)['tankIndex'], 0);
        expect(point['ppO2'], closeTo(0.32, 1e-6));
        // Minutes in the column, seconds in the profile point, as the XML
        // path already does for ndl.
        expect(point['ndl'], 60 * 60);
        expect(point['tts'], 60);
        expect(point.containsKey('heartRate'), isFalse);
        expect(point.containsKey('ceiling'), isFalse);
      });

      test('fractional sample times round to the nearest second', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Manual',
            samples: _zsamples([
              (0.0, 0.0, 200.0, 99, 0.21, 22.0, 0),
              (2.4, 1.0, 200.0, 99, 0.21, 22.0, 0),
              (7.6, 2.0, 200.0, 99, 0.21, 22.0, 0),
            ]),
          ),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        final stamps = (dive['profile'] as List).map(
          (p) => (p as Map)['timestamp'],
        );
        expect(stamps, [0, 2, 8]);
        // Runtime is rounded the same way, so it agrees with the last point.
        expect(dive['runtime'], const Duration(seconds: 8));
      });

      test('zero readings are omitted rather than charted', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Manual',
            samples: _zsamples([(0.0, 0.0, 0.0, 99, 0.0, 22.0, 0)]),
          ),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        final point = (dive['profile'] as List).single as Map<String, dynamic>;
        expect(point.containsKey('allTankPressures'), isFalse);
        expect(point.containsKey('ppO2'), isFalse);
        expect(point['temperature'], 22.0);
      });

      test('samples fill scalar gaps but never override MacDive', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Manual',
            samples: _zsamples([
              (0.0, 0.0, 200.0, 99, 0.21, 24.0, 0),
              (600.0, 18.0, 150.0, 20, 0.6, 21.0, 0),
              (900.0, 3.0, 120.0, 40, 0.27, 23.0, 0),
            ]),
            maxDepth: 18.4,
          ),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive['maxDepth'], 18.4, reason: 'MacDive scalar wins');
        expect(dive['waterTemp'], 21.0);
        expect(dive['runtime'], const Duration(seconds: 900));
      });

      test('runtime is the latest stamp, not the last record', () async {
        // The reference library holds one dive whose samples step backwards
        // once; the decoder passes that through, so the mapper must not
        // trust record order for the dive's length.
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Manual',
            samples: _zsamples([
              (0.0, 0.0, 200.0, 99, 0.21, 24.0, 0),
              (900.0, 3.0, 120.0, 40, 0.27, 23.0, 0),
              (600.0, 18.0, 150.0, 20, 0.6, 21.0, 0),
            ]),
          ),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive['runtime'], const Duration(seconds: 900));
        // Stored order is kept: a restarted clock after a surfacing is a
        // second descent, and sorting would interleave the two segments.
        final stamps = (dive['profile'] as List).map(
          (p) => (p as Map)['timestamp'],
        );
        expect(stamps, [0, 900, 600]);
      });

      test('a rejected raw parse falls back to ZSAMPLES silently', () async {
        // Shearwater dives in the reference library have both columns. A raw
        // parse the sanity check throws out used to cost the dive its profile
        // and earn a warning; now the samples cover it.
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Shearwater Teric',
            raw: _compressedFixture,
            samples: _zsamples([
              (0.0, 0.0, 200.0, 99, 0.21, 24.0, 0),
              (60.0, 12.0, 190.0, 50, 0.46, 22.0, 0),
            ]),
          ),
          fetchDescriptors: _fakeDescriptors,
          parseRaw: (v, p, m, d) async => _parsedDive(
            samples: [
              pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
              pigeon.ProfileSample(timeSeconds: 600, depthMeters: 4000.0),
            ],
          ),
        );

        expect(payload.warnings, isEmpty);
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        final profile = dive['profile'] as List;
        expect(profile, hasLength(2));
        expect((profile.last as Map)['depth'], closeTo(12.0, 1e-6));
      });

      test('a successful raw parse still takes precedence', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Shearwater Teric',
            raw: _compressedFixture,
            samples: _zsamples([(0.0, 0.0, 200.0, 99, 0.21, 24.0, 0)]),
          ),
          fetchDescriptors: _fakeDescriptors,
          parseRaw: (v, p, m, d) async => _parsedDive(
            samples: [
              pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
              pigeon.ProfileSample(timeSeconds: 30, depthMeters: 7.0),
            ],
          ),
        );
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive['profile'], hasLength(2));
      });

      test('without a platform channel ZSAMPLES still decode', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Shearwater Teric',
            raw: _compressedFixture,
            samples: _zsamples([
              (0.0, 0.0, 200.0, 99, 0.21, 24.0, 0),
              (60.0, 12.0, 190.0, 50, 0.46, 22.0, 0),
            ]),
          ),
          fetchDescriptors: () async => throw MissingPluginException('none'),
        );
        expect(payload.warnings, isEmpty);
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive['profile'], hasLength(2));
      });

      test('an empty sample array is not a failure', () async {
        // MacDive stores a header-only blob for a dive with no samples.
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(computer: 'Manual', samples: _zsamples(const [])),
        );
        expect(payload.warnings, isEmpty);
        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        expect(dive.containsKey('profile'), isFalse);
      });

      test(
        'without a channel, unreadable samples still get the XML hint',
        () async {
          // Two dives without a profile for two different reasons: one whose
          // samples were read and rejected (the XML export can rescue it) and
          // one whose only bytes are a raw download this platform cannot try.
          // Lumping both under "this platform" would hide the remedy for the
          // first, so each cause gets its own warning.
          final logbook = _samplesLogbook(
            computer: 'Shearwater Teric',
            raw: _compressedFixture,
            samples: Uint8List.fromList(List.filled(64, 0x42)),
          );
          final payload = await MacDiveDiveMapper.toPayload(
            MacDiveRawLogbook(
              dives: [
                ...logbook.dives,
                MacDiveRawDive(
                  pk: 2,
                  uuid: 'dive-2',
                  computer: 'Shearwater Teric',
                  rawDataBlob: _compressedFixture,
                ),
              ],
              sitesByPk: const {},
              buddiesByPk: const {},
              tagsByPk: const {},
              gearByPk: const {},
              tanksByPk: const {},
              gasesByPk: const {},
              tankAndGases: const [],
              crittersByPk: const {},
              certifications: const [],
              serviceRecords: const [],
              events: const [],
              diveToBuddyPks: const {},
              diveToTagPks: const {},
              diveToGearPks: const {},
              diveToCritterPks: const {},
              unitsPreference: 'Metric',
            ),
            fetchDescriptors: () async => throw MissingPluginException('none'),
          );

          expect(payload.warnings, hasLength(2));
          final messages = payload.warnings.map((w) => w.message).toList();
          expect(
            messages.where((m) => m.startsWith('1 dive') && m.contains('XML')),
            hasLength(1),
          );
          expect(
            messages.where(
              (m) => m.startsWith('1 dive') && m.contains('this platform'),
            ),
            hasLength(1),
          );
        },
      );

      test('an empty sample array beside a failed raw parse warns', () async {
        // MacDive drawing no profile is only the whole story when ZSAMPLES
        // was the dive's only source. Here the raw download was there too and
        // its parse was thrown out, so the dive lost a profile the XML export
        // can still rescue - and reporting nothing would hide that.
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Shearwater Teric',
            raw: _compressedFixture,
            samples: _zsamples(const []),
          ),
          fetchDescriptors: _fakeDescriptors,
          parseRaw: (v, p, m, d) async => _parsedDive(
            samples: [
              pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
              pigeon.ProfileSample(timeSeconds: 600, depthMeters: 4000.0),
            ],
          ),
        );

        expect(payload.warnings, hasLength(1));
        expect(payload.warnings.single.message, contains('1 dive'));
        expect(payload.warnings.single.message, contains('XML'));
      });

      test(
        'an empty sample array without a channel blames the platform',
        () async {
          // Same dive, but the raw bytes were never attempted. An XML export
          // would not help: MacDive has no profile of its own to export.
          final payload = await MacDiveDiveMapper.toPayload(
            _samplesLogbook(
              computer: 'Shearwater Teric',
              raw: _compressedFixture,
              samples: _zsamples(const []),
            ),
            fetchDescriptors: () async => throw MissingPluginException('none'),
          );

          expect(payload.warnings, hasLength(1));
          expect(payload.warnings.single.message, contains('this platform'));
        },
      );

      test(
        'sample pressures set the unit for a cylinder-less library',
        () async {
          // No units row and no cylinder rows, so the sample pressures are the
          // only witness there is. Charting 3000 psi as 3000 bar is #912.
          final payload = await MacDiveDiveMapper.toPayload(
            _samplesLogbook(
              computer: 'Manual',
              samples: _zsamples([(0.0, 0.0, 3000.0, 99, 0.21, 27.5, 0)]),
              unitsPreference: null,
            ),
          );

          expect(payload.metadata['units'], 'imperial');
          final dive = payload.entitiesOf(ImportEntityType.dives).single;
          final point =
              (dive['profile'] as List).single as Map<String, dynamic>;
          final pressure = (point['allTankPressures'] as List).single as Map;
          expect(pressure['pressure'], closeTo(3000 * 0.0689476, 1e-3));
        },
      );

      test('a pressure with no unit to place it in is dropped', () async {
        // The inference scan is bounded, so a library whose only pressures
        // sit past the limit still resolves to unknown. Passing those through
        // would chart psi as bar; leaving them out costs a channel the dive
        // did not have before ZSAMPLES were readable at all.
        final blobs = [
          for (var i = 0; i <= MacDiveUnitInference.sampleScanDiveLimit; i++)
            _zsamples([
              (
                0.0,
                3.0,
                i < MacDiveUnitInference.sampleScanDiveLimit ? 0.0 : 3000.0,
                99,
                0.21,
                24.0,
                0,
              ),
            ]),
        ];
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesOnlyLogbook(blobs),
        );

        expect(payload.metadata['units'], 'unknown');
        final dives = payload.entitiesOf(ImportEntityType.dives);
        final last = (dives.last['profile'] as List).single as Map;
        expect(last.containsKey('allTankPressures'), isFalse);
        // Everything that does not depend on the unit still arrives.
        expect(last['depth'], closeTo(3.0, 1e-6));
        expect(last['temperature'], closeTo(24.0, 1e-6));
      });

      test('heart rate and ceiling reach the profile point', () async {
        // The Teric options word every other test here uses carries neither,
        // so these two channels - the ones ZSAMPLES can supply that MacDive's
        // own XML export cannot - had no test asserting they arrive.
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Manual',
            samples: _zsamplesPulseAndStop([
              (0.0, 0.0, 70, 0.0),
              (60.0, 30.0, 75, 3.0),
            ]),
          ),
        );

        final dive = payload.entitiesOf(ImportEntityType.dives).single;
        final profile = dive['profile'] as List;
        final descent = profile.last as Map<String, dynamic>;
        expect(descent['heartRate'], 75);
        expect(descent['ceiling'], closeTo(3.0, 1e-6));
        // A zero next stop is MacDive's "no reading", not a stop at the
        // surface, so it stays out the way a zero pressure does.
        expect((profile.first as Map).containsKey('ceiling'), isFalse);
        expect((profile.first as Map)['heartRate'], 70);
      });

      test('unreadable ZSAMPLES count toward the aggregated warning', () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _samplesLogbook(
            computer: 'Oceanic Matrix Master',
            samples: Uint8List.fromList(List.filled(64, 0x42)),
          ),
        );

        expect(payload.warnings, hasLength(1));
        expect(payload.warnings.single.message, contains('1 dive'));
        expect(payload.warnings.single.message.toLowerCase(), contains('xml'));
      });
    });

    test('no warning when logbook has no ZRAWDATA', () async {
      const logbook = MacDiveRawLogbook(
        dives: [
          MacDiveRawDive(
            pk: 1,
            uuid: 'dive-1',
            computer: 'Manual',
            rawDataBlob: null,
          ),
        ],
        sitesByPk: {},
        buddiesByPk: {},
        tagsByPk: {},
        gearByPk: {},
        tanksByPk: {},
        gasesByPk: {},
        tankAndGases: [],
        crittersByPk: {},
        certifications: [],
        serviceRecords: [],
        events: [],
        diveToBuddyPks: {},
        diveToTagPks: {},
        diveToGearPks: {},
        diveToCritterPks: {},
        unitsPreference: 'Metric',
      );
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.warnings, isEmpty);
    });

    test('metadata includes source identifier and dive count', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.metadata['source'], 'macdive_sqlite');
      expect(payload.metadata['diveCount'], 3);
    });

    test('site entity carries sourceUuid from ZDIVESITE.ZUUID', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final salt = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Test Reef');
      expect(salt['sourceUuid'], 'site-uuid-1');
    });
  });
}

/// A Shearwater-compressed log, byte-identical to the fixture in
/// shearwater_raw_decompressor_test.dart, so this test exercises the real
/// decompression path rather than a stub.
final _compressedFixture = _hex(
  '8801e021780c040d010bc0e061e80c043d078387a03010f4'
  '520a0ca70360bdc02660351401c076a0b8183ac404f502e0'
  '20e9d80e079f05c1c1dff02438352501c0f280b8383acc04'
  'f702e020e9c80e03ba05c0c1d14026583301f600a420da70'
  '3609ec01406021e81c0c3d018087a0f070f406021eed4143'
  'c00000000000',
);

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

pigeon.DeviceDescriptor _descriptor(String vendor, String product, int model) =>
    pigeon.DeviceDescriptor(
      vendor: vendor,
      product: product,
      model: model,
      transports: const [pigeon.TransportType.ble],
    );

/// A slice of what `getDeviceDescriptors()` returns, with the real vendor,
/// product and model values from libdivecomputer's `descriptor.c`. The full
/// list is a few hundred entries across thirty-odd vendors; these cover the
/// cases the mapper has to get right - one Shearwater (the only vendor
/// needing a pre-pass), the three Suunto models #1400 hardcoded, a Suunto and
/// a Mares that were unreachable before #1436, and a product name
/// libdivecomputer declares twice.
Future<List<pigeon.DeviceDescriptor>> _fakeDescriptors() async => [
  _descriptor('Shearwater', 'Teric', 8),
  _descriptor('Shearwater', 'Tern', 12),
  _descriptor('Suunto', 'EON Steel', 0),
  _descriptor('Suunto', 'D5', 2),
  _descriptor('Suunto', 'EON Steel Black', 3),
  _descriptor('Suunto', 'Cobra', 0x0C),
  _descriptor('Suunto', 'Zoop Novo', 0x1E),
  _descriptor('Suunto', 'Zoop Novo', 0x1F),
  _descriptor('Mares', 'Puck 4', 0x35),
  _descriptor('Oceanic', 'Geo 4.0', 0x4653),
];

/// Stand-in for a Suunto `ZRAWDATA` blob. The real format (SBEM for EON
/// Steel, the Vyper dive-header layout for Cobra) is confirmed elsewhere
/// against real MacDive data; these tests stub `parseRaw`, so the bytes never
/// have to be a valid dive - but their shape is chosen so that any accidental
/// Shearwater-style transformation would visibly alter them:
///
/// * longer than 32 bytes, so [ShearwaterRawDecompressor.applyXorDelta] (which
///   preserves length and would therefore slip past a length-only check) has
///   blocks to fold together;
/// * non-uniform, so that XOR fold produces different bytes rather than a
///   coincidentally identical buffer;
/// * 45 bytes, i.e. a bit count divisible by 9, so
///   [ShearwaterRawDecompressor.decompressLre] would accept the stream instead
///   of rejecting it as malformed and short-circuiting the test.
final _suuntoFixture = Uint8List.fromList(
  List.generate(45, (i) => (i * 7 + 3) & 0xFF),
);

/// One dive on [computer] carrying [raw] as its `ZRAWDATA`.
MacDiveRawLogbook _suuntoRawDataLogbook({
  required String computer,
  required Uint8List raw,
}) {
  return MacDiveRawLogbook(
    dives: [
      MacDiveRawDive(
        pk: 1,
        uuid: 'dive-1',
        computer: computer,
        rawDataBlob: raw,
      ),
    ],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}

/// One dive on [computer] carrying [samples] as its `ZSAMPLES` and,
/// optionally, [raw] as its `ZRAWDATA`.
MacDiveRawLogbook _samplesLogbook({
  required String computer,
  required Uint8List samples,
  Uint8List? raw,
  double? maxDepth,
  String? unitsPreference = 'Metric',
}) {
  return MacDiveRawLogbook(
    dives: [
      MacDiveRawDive(
        pk: 1,
        uuid: 'dive-1',
        computer: computer,
        maxDepth: maxDepth,
        samplesBlob: samples,
        rawDataBlob: raw,
      ),
    ],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: unitsPreference,
  );
}

/// A samples-only logbook of one dive per entry in [samples], with no
/// cylinder rows, for exercising what the unit inference makes of the sample
/// pressures themselves.
MacDiveRawLogbook _samplesOnlyLogbook(
  List<Uint8List> samples, {
  String? unitsPreference,
}) {
  return MacDiveRawLogbook(
    dives: [
      for (final (index, blob) in samples.indexed)
        MacDiveRawDive(
          pk: index + 1,
          uuid: 'dive-${index + 1}',
          computer: 'Manual',
          samplesBlob: blob,
        ),
    ],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: unitsPreference,
  );
}

/// Encodes a `ZSAMPLES` blob the way MacDive does for a Shearwater Teric:
/// version 4, options 0x9D (pressure, NDT, ppO2, temperature, TTS), records
/// packed little-endian, padded to a TEA block, a trailing block carrying
/// the byte length, and the whole body TEA-ECB encrypted under the app key.
/// Each record is (time s, depth m, pressure, ndt min, ppO2, temp C, tts min).
Uint8List _zsamples(
  List<(double, double, double, int, double, double, int)> records,
) {
  const options =
      MacDiveSamplesDecoder.optionPressure |
      MacDiveSamplesDecoder.optionNdt |
      MacDiveSamplesDecoder.optionPpO2 |
      MacDiveSamplesDecoder.optionTemperature |
      MacDiveSamplesDecoder.optionTts;
  const stride = 28;
  final packed = Uint8List(records.length * stride);
  final data = ByteData.sublistView(packed);
  for (var i = 0; i < records.length; i++) {
    final (time, depth, pressure, ndt, ppO2, temp, tts) = records[i];
    data
      ..setFloat32(i * stride, time, Endian.little)
      ..setFloat32(i * stride + 4, depth, Endian.little)
      ..setFloat32(i * stride + 8, pressure, Endian.little)
      ..setInt32(i * stride + 12, ndt, Endian.little)
      ..setFloat32(i * stride + 16, ppO2, Endian.little)
      ..setFloat32(i * stride + 20, temp, Endian.little)
      ..setInt32(i * stride + 24, tts, Endian.little);
  }
  final blocks = (packed.length + 7) ~/ 8 + 1;
  final plain = Uint8List(blocks * 8)..setRange(0, packed.length, packed);
  ByteData.sublistView(
    plain,
  ).setUint32(plain.length - 4, packed.length, Endian.little);

  const cipher = MacDiveSamplesDecoder.cipher;
  final blob = Uint8List(8 + plain.length);
  ByteData.sublistView(blob)
    ..setUint32(0, 4, Endian.little)
    ..setUint32(4, options, Endian.little);
  blob.setRange(8, blob.length, cipher.encrypt(plain));
  return blob;
}

/// A `ZSAMPLES` blob carrying only heart rate and next-stop depth, the two
/// optional fields no other fixture here sets. Records are
/// (time s, depth m, bpm, next stop m); in the encoder's emission order heart
/// rate precedes next-stop depth, so the stride is 16.
Uint8List _zsamplesPulseAndStop(List<(double, double, int, double)> records) {
  const options =
      MacDiveSamplesDecoder.optionHeartRate |
      MacDiveSamplesDecoder.optionNextStopDepth;
  const stride = 16;
  final packed = Uint8List(records.length * stride);
  final data = ByteData.sublistView(packed);
  for (var i = 0; i < records.length; i++) {
    final (time, depth, heartRate, nextStop) = records[i];
    data
      ..setFloat32(i * stride, time, Endian.little)
      ..setFloat32(i * stride + 4, depth, Endian.little)
      ..setInt32(i * stride + 8, heartRate, Endian.little)
      ..setFloat32(i * stride + 12, nextStop, Endian.little);
  }
  final plain = Uint8List(((packed.length + 7) ~/ 8 + 1) * 8)
    ..setRange(0, packed.length, packed);
  ByteData.sublistView(
    plain,
  ).setUint32(plain.length - 4, packed.length, Endian.little);

  final blob = Uint8List(8 + plain.length);
  ByteData.sublistView(blob)
    ..setUint32(0, 4, Endian.little)
    ..setUint32(4, options, Endian.little);
  blob.setRange(8, blob.length, MacDiveSamplesDecoder.cipher.encrypt(plain));
  return blob;
}

/// Two dives carrying a real compressed blob plus one manual dive with none.
MacDiveRawLogbook _rawDataLogbook({String computer = 'Shearwater Teric'}) {
  return MacDiveRawLogbook(
    dives: [
      MacDiveRawDive(
        pk: 1,
        uuid: 'dive-1',
        computer: computer,
        rawDataBlob: _compressedFixture,
      ),
      MacDiveRawDive(
        pk: 2,
        uuid: 'dive-2',
        computer: computer,
        rawDataBlob: _compressedFixture,
      ),
      const MacDiveRawDive(pk: 3, uuid: 'dive-3', computer: 'Manual'),
    ],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}

/// Three dives across two MacDive divers, plus one dive with no diver link.
/// With [singleDiver] the second diver is removed, so the library looks like
/// the common one-diver case.
MacDiveRawLogbook _multiDiverLogbook({bool singleDiver = false}) {
  return MacDiveRawLogbook(
    dives: const [
      MacDiveRawDive(pk: 1, uuid: 'dive-1', diverFk: 1),
      MacDiveRawDive(pk: 2, uuid: 'dive-2', diverFk: 2),
      MacDiveRawDive(pk: 3, uuid: 'dive-3'),
    ],
    diversByPk: {
      1: const MacDiveRawDiver(
        pk: 1,
        uuid: 'diver-1',
        firstName: 'Ann',
        lastName: 'Lee',
      ),
      if (!singleDiver)
        2: const MacDiveRawDiver(
          pk: 2,
          uuid: 'diver-2',
          firstName: 'Bo',
          lastName: 'Ray',
        ),
    },
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}

pigeon.ParsedDive _parsedDive({required List<pigeon.ProfileSample> samples}) {
  return pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 3,
    dateTimeDay: 11,
    dateTimeHour: 14,
    dateTimeMinute: 9,
    dateTimeSecond: 18,
    maxDepthMeters: 25.4,
    avgDepthMeters: 17.6,
    durationSeconds: 3100,
    samples: samples,
    tanks: [],
    gasMixes: [],
    events: [],
  );
}

/// One dive whose only interesting column is `ZSURFACEINTERVAL`.
MacDiveRawLogbook _surfaceIntervalLogbook(double surfaceInterval) {
  return MacDiveRawLogbook(
    dives: [
      MacDiveRawDive(pk: 1, uuid: 'dive-1', surfaceInterval: surfaceInterval),
    ],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}
