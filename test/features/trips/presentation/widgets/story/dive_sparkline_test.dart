import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/dive_sparkline.dart';

Future<void> pumpSparkline(
  WidgetTester tester,
  String diveId,
  List<DiveProfilePoint> profile,
) async {
  await tester.pumpWidget(
    ProviderScope(
      // The sparkline loads the primary-only profile via diveProfileProvider;
      // override it so the test drives the curve without a repository/DB.
      overrides: [
        diveProfileProvider(diveId).overrideWith((ref) async => profile),
      ],
      child: MaterialApp(
        home: Scaffold(body: DiveSparkline(diveId: diveId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a CustomPaint for a real profile', (tester) async {
    final profile = List.generate(
      50,
      (i) => DiveProfilePoint(timestamp: i * 30, depth: (i % 10) + 5.0),
    );
    await pumpSparkline(tester, 'd1', profile);
    expect(
      find.descendant(
        of: find.byType(DiveSparkline),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing for an empty profile', (tester) async {
    await pumpSparkline(tester, 'd2', const []);
    expect(
      find.descendant(
        of: find.byType(DiveSparkline),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
