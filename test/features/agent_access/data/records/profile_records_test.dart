import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/documents/profile_documents.dart';
import 'package:submersion/features/agent_access/data/tools/list_divers_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    await (db.update(db.divers)..where((d) => d.id.equals(kDiverA))).write(
      DiversCompanion(
        email: const Value('a@example.com'),
        medicalNotes: const Value('Asthma as a child'),
        bloodType: const Value('O+'),
        emergencyContactName: const Value('Sam'),
        emergencyContactPhone: const Value('+1 555'),
        photo: Value(Uint8List.fromList([1, 2, 3])),
      ),
    );
    // A diver's insurance is read from their primary insurance document.
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            id: 'insurance',
            diverId: kDiverA,
            type: 'insurance',
            createdAt: t,
            updatedAt: t,
            issuer: const Value('DAN'),
            referenceNumber: const Value('P-1'),
            expiryDate: Value(DateTime(2027, 1, 31).millisecondsSinceEpoch),
            emergencyPhone: const Value('+1 919'),
            isPrimary: const Value(true),
          ),
        );
    for (final (id, owner) in [('set-a', kDiverA), ('set-b', kDiverB)]) {
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: id,
              diverId: owner,
              createdAt: t,
              updatedAt: t,
              defaultTankVolume: const Value(12),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  group('divers', () {
    test('a diver record carries medical notes and insurance', () async {
      final doc = (await h.one('divers', kDiverA))!;
      expect(doc['email'], 'a@example.com');
      expect(doc['medical_notes'], 'Asthma as a child');
      expect(doc['blood_type'], 'O+');
      expect((doc['emergency_contact'] as Map)['name'], 'Sam');
      expect((doc['insurance'] as Map)['policy_number'], 'P-1');
      expect((doc['insurance'] as Map)['expiry_date'], '2027-01-31');
      expect((doc['insurance'] as Map)['emergency_phone'], '+1 919');
    });

    test('a diver record carries no photo bytes', () async {
      final doc = (await h.one('divers', kDiverA))!;
      expect(doc.keys, isNot(contains('photo')));
    });

    test('every profile reads from any other', () async {
      expect(await h.one('divers', kDiverA, diverId: kDiverB), isNotNull);
      expect((await h.list('divers')).toSet(), {kDiverA, kDiverB});
    });

    test('list_divers stays a whitelist', () async {
      final divers = DiverRepository();
      final settings = DiverSettingsRepository();
      final out = await ListDiversTool(
        loader: DiverContextLoader(
          db: () => db,
          divers: divers,
          settings: settings,
          localeTag: 'en',
          activeDiverId: () async => kDiverA,
        ),
        divers: divers,
        settings: settings,
      ).call({}, AgentToolContext(db: db, clientName: 'test'));
      final row = (out['divers'] as List).cast<Map>().first;
      expect(row.containsKey('medical_notes'), isFalse);
      expect(row.containsKey('email'), isFalse);
    });
  });

  group('diver_settings', () {
    test('diver settings read as that profile', () async {
      final doc = (await h.one('diver_settings', 'set-a'))!;
      expect(doc['diver_id'], kDiverA);
      expect(doc['default_tank_volume_l'], 12.0);
      expect(doc['depth_unit'], 'meters');
      expect(doc.keys, isNot(contains('default_tank_volume')));
    });

    test('another diver\'s settings are missing', () async {
      expect(await h.one('diver_settings', 'set-b'), isNull);
      expect(await h.list('diver_settings'), ['set-a']);
    });

    test('device-local and bookkeeping columns stay out', () async {
      final doc = (await h.one('diver_settings', 'set-a'))!;
      for (final key in [
        'theme_mode',
        'notifications_enabled',
        'service_reminder_days',
        'reminder_time',
        'trip_service_lead_days',
        'created_at',
        'updated_at',
        'hlc',
      ]) {
        expect(doc.keys, isNot(contains(key)), reason: key);
      }
      expect(doc.keys.where((k) => k.endsWith('_hlc')), isEmpty);
    });
  });

  test(
    'every real settings column is unit-named or declared unitless',
    () async {
      final columns = await db
          .customSelect(
            "SELECT name, type FROM pragma_table_info('diver_settings')",
          )
          .get();
      final reals = [
        for (final c in columns)
          if (c.read<String>('type') == 'REAL') c.read<String>('name'),
      ];
      expect(reals, isNotEmpty);
      for (final column in reals) {
        expect(
          kSettingUnitKeys.containsKey(column) ||
              kUnitlessSettings.contains(column),
          isTrue,
          reason: '$column needs a unit decision',
        );
      }
    },
  );
}
