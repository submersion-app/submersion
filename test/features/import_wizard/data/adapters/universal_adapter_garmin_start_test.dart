import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Records what the wizard asks of the import, without touching a device.
class _RecordingNotifier extends UniversalImportNotifier {
  _RecordingNotifier(super.ref);

  final calls = <String>[];

  @override
  void reset() {
    calls.add('reset');
    super.reset();
  }

  final requests = <GarminImportRequest>[];

  @override
  Future<void> importFromGarminDevice([
    GarminImportRequest request = const GarminImportRequest(),
  ]) async {
    calls.add('garmin');
    requests.add(request);
  }
}

/// Opening the wizard from Connect New Computer, or from a saved Garmin,
/// starts the Garmin device import once the wizard has reset (issue #4223).
void main() {
  late ProviderContainer container;
  late _RecordingNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        universalImportNotifierProvider.overrideWith((ref) {
          return notifier = _RecordingNotifier(ref);
        }),
      ],
    );
    container.read(universalImportNotifierProvider);
  });

  tearDown(() => container.dispose());

  Future<UniversalAdapter> pumpAdapter(
    WidgetTester tester, {
    GarminImportRequest? garminImport,
  }) async {
    late UniversalAdapter adapter;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              adapter = UniversalAdapter(ref: ref, garminImport: garminImport);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return adapter;
  }

  testWidgets('starts the Garmin import after the first reset only', (
    tester,
  ) async {
    const request = GarminImportRequest(computerId: 'dc-1', readAll: true);
    final adapter = await pumpAdapter(tester, garminImport: request);

    adapter.resetState();
    adapter.resetState();

    expect(notifier.calls, ['reset', 'garmin', 'reset']);
    expect(notifier.requests, [request]);
  });

  testWidgets('a plain file import only resets', (tester) async {
    final adapter = await pumpAdapter(tester);

    adapter.resetState();

    expect(notifier.calls, ['reset']);
  });
}
