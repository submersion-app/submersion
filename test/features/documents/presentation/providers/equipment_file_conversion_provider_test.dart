import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fake = _CountingConverter(await SharedPreferences.getInstance());
    container = ProviderContainer(
      overrides: [
        equipmentFileConverterFactoryProvider.overrideWithValue(
          () async => fake,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('overlapping runs share one conversion', () async {
    final run = container.read(equipmentFileConversionProvider);
    await Future.wait([run(), run()]);
    expect(fake.runs, 1);
  });

  test('a later run starts a new conversion', () async {
    final run = container.read(equipmentFileConversionProvider);
    await run();
    await run();
    expect(fake.runs, 2);
  });

  test('a failure is contained and reported as null', () async {
    fake.failWith = StateError('disk');
    final result = await container.read(equipmentFileConversionProvider)();
    expect(result, isNull);
  });
}
