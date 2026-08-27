import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';

/// Pumps a bare consumer purely to hand [resetSurfaceIntervalInputs] a
/// [WidgetRef], which is the only thing it accepts.
Future<(WidgetRef, ProviderContainer)> _pumpRef(WidgetTester tester) async {
  late WidgetRef captured;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, child) {
            captured = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(SizedBox)),
  );
  return (captured, container);
}

void main() {
  testWidgets('resetSurfaceIntervalInputs restores every input to default', (
    tester,
  ) async {
    final (ref, container) = await _pumpRef(tester);

    // Move every input off its default, including both dives' gas.
    container.read(siFirstDiveDepthProvider.notifier).state = 42.0;
    container.read(siFirstDiveTimeProvider.notifier).state = 11;
    container.read(siFirstDiveO2Provider.notifier).state = 32.0;
    container.read(siFirstDiveHeProvider.notifier).state = 25.0;
    container.read(siSecondDiveDepthProvider.notifier).state = 37.0;
    container.read(siSecondDiveTimeProvider.notifier).state = 13;
    container.read(siSecondDiveO2Provider.notifier).state = 40.0;
    container.read(siSecondDiveHeProvider.notifier).state = 15.0;
    container.read(siSurfaceIntervalProvider.notifier).state = 240;

    resetSurfaceIntervalInputs(ref);
    await tester.pump();

    expect(container.read(siFirstDiveDepthProvider), 18.0);
    expect(container.read(siFirstDiveTimeProvider), 45);
    expect(container.read(siFirstDiveO2Provider), 21.0);
    expect(container.read(siFirstDiveHeProvider), 0.0);
    expect(container.read(siSecondDiveDepthProvider), 18.0);
    expect(container.read(siSecondDiveTimeProvider), 45);
    expect(
      container.read(siSecondDiveO2Provider),
      21.0,
      reason: 'second dive gas must reset with everything else',
    );
    expect(container.read(siSecondDiveHeProvider), 0.0);
    expect(container.read(siSurfaceIntervalProvider), 60);
  });

  testWidgets('reset leaves both dives on matching air mixes', (tester) async {
    final (ref, container) = await _pumpRef(tester);

    container.read(siFirstDiveO2Provider.notifier).state = 32.0;
    container.read(siSecondDiveO2Provider.notifier).state = 40.0;
    container.read(siSecondDiveHeProvider.notifier).state = 20.0;

    resetSurfaceIntervalInputs(ref);
    await tester.pump();

    expect(
      container.read(siSecondDiveFN2Provider),
      container.read(siFirstDiveFN2Provider),
    );
    expect(
      container.read(siSecondDiveFHeProvider),
      container.read(siFirstDiveFHeProvider),
    );
  });
}
