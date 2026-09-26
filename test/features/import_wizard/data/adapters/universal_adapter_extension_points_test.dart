import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The seams a source that fetches its payload builds on: the steps that act
/// on any payload, and the hook for photos only that source brings.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  Future<UniversalAdapter> pumpAdapter(WidgetTester tester) async {
    late UniversalAdapter adapter;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              adapter = UniversalAdapter(ref: ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return adapter;
  }

  testWidgets('file steps come first, then the payload steps', (tester) async {
    final adapter = await pumpAdapter(tester);
    expect(adapter.acquisitionSteps.map((s) => s.label).toList(), [
      'Select File',
      'Confirm Source',
      'Map Fields',
      'Divers',
      'Photos',
    ]);
    expect(adapter.debugPayloadStepLabels, ['Divers', 'Photos']);
  });

  testWidgets('the default photo hook attaches nothing', (tester) async {
    final adapter = await pumpAdapter(tester);
    final outcome = await adapter.debugAttachAdditionalPhotos();
    expect(outcome, (attached: 0, failed: 0));
  });
}
