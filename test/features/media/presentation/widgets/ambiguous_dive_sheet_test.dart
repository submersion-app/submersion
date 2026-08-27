import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/widgets/ambiguous_dive_sheet.dart';

void main() {
  Widget host(String diveId, Dive? dive) {
    return ProviderScope(
      overrides: [diveProvider(diveId).overrideWith((ref) async => dive)],
      child: MaterialApp(
        home: Scaffold(
          body: AmbiguousDiveTile(diveId: diveId, onTap: () {}),
        ),
      ),
    );
  }

  testWidgets('a numbered dive shows its number', (tester) async {
    await tester.pumpWidget(
      host(
        'd1',
        Dive(id: 'd1', diveNumber: 7, dateTime: DateTime(2026, 6, 12)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('#7'), findsOneWidget);
  });

  testWidgets('a dive with no number, name, or site falls back to its id', (
    tester,
  ) async {
    // Nothing to show would otherwise be an empty title.
    await tester.pumpWidget(
      host('d1', Dive(id: 'd1', dateTime: DateTime(2026, 6, 12))),
    );
    await tester.pumpAndSettle();
    expect(find.text('d1'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('a named dive shows its number and name', (tester) async {
    await tester.pumpWidget(
      host(
        'd1',
        Dive(
          id: 'd1',
          diveNumber: 3,
          name: 'Night wreck',
          dateTime: DateTime(2026, 6, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('#3 Night wreck'), findsOneWidget);
  });

  testWidgets('an unnamed dive falls back to its site name', (tester) async {
    await tester.pumpWidget(
      host(
        'd2',
        Dive(
          id: 'd2',
          dateTime: DateTime(2026, 6, 12),
          site: const DiveSite(id: 's1', name: 'Blue Hole'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('the sheet lists the candidates and resolves the tapped id', (
    tester,
  ) async {
    String? picked = 'sentinel';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveProvider('d1').overrideWith(
            (ref) async =>
                Dive(id: 'd1', diveNumber: 1, dateTime: DateTime(2026, 6, 12)),
          ),
          diveProvider('d2').overrideWith(
            (ref) async =>
                Dive(id: 'd2', diveNumber: 2, dateTime: DateTime(2026, 6, 12)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await showAmbiguousDiveSheet(
                  context,
                  const ['d1', 'd2'],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();

    expect(picked, 'd2');
  });
}
