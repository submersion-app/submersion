import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/diver_document.dart';
import 'package:submersion/features/agent_access/data/tools/list_divers_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const active = 'active-diver';
  const feet = 'feet-diver';
  const t = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final (id, isDefault) in [(active, true), (feet, false)]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: 'Name of $id',
              createdAt: t,
              updatedAt: t,
              isDefault: Value(isDefault),
              email: const Value('secret@example.com'),
            ),
          );
    }
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive-$i',
              diveDateTime: t + i,
              createdAt: t,
              updatedAt: t,
              diverId: const Value(active),
            ),
          );
    }
    await DiverSettingsRepository().createSettingsForDiver(
      feet,
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        weightUnit: WeightUnit.pounds,
        timeFormat: TimeFormat.twentyFourHour,
        dateFormat: DateFormatPreference.yyyymmdd,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  ListDiversTool tool() {
    final divers = DiverRepository();
    final settings = DiverSettingsRepository();
    return ListDiversTool(
      loader: DiverContextLoader(
        db: db,
        divers: divers,
        settings: settings,
        localeTag: 'en',
        activeDiverId: () async => active,
      ),
      divers: divers,
      settings: settings,
    );
  }

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  group('ListDiversTool', () {
    test('is named list_divers and takes no arguments', () {
      expect(tool().name, 'list_divers');
      expect(tool().inputSchema['type'], 'object');
      expect(tool().inputSchema['properties'], isEmpty);
    });

    test('lists every profile with units and active flag', () async {
      final out = await tool().call({}, ctx());
      final divers = (out['divers'] as List).cast<Map<String, Object?>>();
      expect(divers, hasLength(2));
      final a = divers.singleWhere((d) => d['id'] == active);
      expect(a['name'], 'Name of $active');
      expect(a['is_active'], isTrue);
      expect(a['is_default'], isTrue);
      expect(a['dive_count'], 3);
      expect(a['units'], {
        'depth': 'm',
        'temperature': 'c',
        'pressure': 'bar',
        'volume': 'l',
        'weight': 'kg',
      });
      expect(a['date_format'], 'MMM d, yyyy');
      expect(a['time_format'], '12h');
      final f = divers.singleWhere((d) => d['id'] == feet);
      expect(f['is_active'], isFalse);
      expect(f['dive_count'], 0);
      expect(f['units'], {
        'depth': 'ft',
        'temperature': 'f',
        'pressure': 'psi',
        'volume': 'cuft',
        'weight': 'lb',
      });
      expect(f['date_format'], 'yyyy-MM-dd');
      expect(f['time_format'], '24h');
    });

    test('document never includes email, phone, medical or photo fields', () {
      final doc = diverDocument(
        domain.Diver(
          id: 'd',
          name: 'n',
          email: 'e@example.com',
          phone: '1',
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
        ),
        isActive: false,
        diveCount: 0,
        settings: const AppSettings(),
      );
      expect(
        doc.keys,
        unorderedEquals([
          'id',
          'name',
          'is_active',
          'is_default',
          'dive_count',
          'units',
          'date_format',
          'time_format',
        ]),
      );
      expect(doc.toString(), isNot(contains('example.com')));
    });
  });
}
