import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/compaction/database_compaction_monitor.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/data/services/equipment_file_converter.dart';
import 'package:submersion/features/documents/presentation/providers/equipment_file_conversion_provider.dart';

class _CountingConverter extends EquipmentFileConverter {
  _CountingConverter(SharedPreferences prefs)
    : super(readBytes: (_) async => null, prefs: prefs);

  int runs = 0;
  Object? failWith;

  @override
  Future<EquipmentFileConversionResult> run() async {
    runs++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (failWith case final error?) throw error;
    return const EquipmentFileConversionResult(0, 0);
  }
}

void main() {
  late _CountingConverter fake;
  late ProviderContainer container;
  var checks = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = _CountingConverter(await SharedPreferences.getInstance());
    checks = 0;
    container = ProviderContainer(
      overrides: [
        databaseCompactionMonitorProvider.overrideWithValue(
          () async => checks++,
        ),
        equipmentFileConverterFactoryProvider.overrideWithValue(
          () async => fake,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a call during a run queues exactly one more', () async {
    final run = container.read(equipmentFileConversionProvider);
    // The launch pass is running when a sync (or two) finishes: the files
    // that sync pulled need a pass of their own, but only one.
    await Future.wait([run(), run(), run()]);
    expect(fake.runs, 2);
  });

  test('a later run starts a new conversion', () async {
    final run = container.read(equipmentFileConversionProvider);
    await run();
    await run();
    expect(fake.runs, 2);
  });

  test(
    'each run then checks free space, even one that converted none',
    () async {
      await container.read(equipmentFileConversionProvider)();
      expect(checks, 1);
    },
  );

  test('a failure is contained and reported as null', () async {
    fake.failWith = StateError('disk');
    final result = await container.read(equipmentFileConversionProvider)();
    expect(result, isNull);
  });
}
