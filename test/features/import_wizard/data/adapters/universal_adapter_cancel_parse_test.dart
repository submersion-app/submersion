// The wizard only knows `onCancelAdvance`. These steps are what connects it to
// the parse, so Back during a real import stops it rather than letting the
// wizard jump forward when the parse ends.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

class _CountingNotifier extends UniversalImportNotifier {
  _CountingNotifier(super.ref);

  int cancels = 0;

  @override
  void cancelParse() => cancels++;
}

void main() {
  for (final label in const ['Confirm Source', 'Map Fields']) {
    testWidgets('$label stops the parse its advance started', (tester) async {
      late _CountingNotifier notifier;
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith(
              (ref) => notifier = _CountingNotifier(ref),
            ),
          ],
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

      final step = adapter.acquisitionSteps.singleWhere(
        (s) => s.label == label,
      );
      step.onCancelAdvance!();

      expect(notifier.cancels, 1);
    });
  }

  test('Confirm Source holds Next while a parse runs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);

    notifier.state = notifier.state.copyWith(
      detectionResult: const DetectionResult(
        format: ImportFormat.subsurfaceXml,
        confidence: 1,
      ),
      isLoading: true,
    );
    expect(container.read(universalAdapterSourceReadyProvider), isFalse);

    notifier.state = notifier.state.copyWith(isLoading: false);
    expect(container.read(universalAdapterSourceReadyProvider), isTrue);
  });
}
