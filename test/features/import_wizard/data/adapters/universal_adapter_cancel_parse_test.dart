// The wizard only knows `onCancelAdvance`. These steps are what connects it to
// the parse, so Back during a real import stops it rather than letting the
// wizard jump forward when the parse ends.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
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
      final notifier = <_CountingNotifier>[];
      late UniversalAdapter adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith((ref) {
              final created = _CountingNotifier(ref);
              notifier.add(created);
              return created;
            }),
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

      expect(notifier.single.cancels, 1);
    });
  }
}
