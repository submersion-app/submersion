import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/pages/incidents_list_page.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Incident incident({
    String? diveId,
    IncidentSeverity severity = IncidentSeverity.moderate,
  }) => Incident(
    id: 'i1',
    occurredAt: DateTime.utc(2026, 7, 10),
    category: IncidentCategory.gasSupply,
    severity: severity,
    narrative: 'Free-flow at 18 m; switched to buddy octo.',
    createdAt: DateTime.utc(2026, 7, 10),
    updatedAt: DateTime.utc(2026, 7, 10),
    diveId: diveId,
  );

  Future<void> pump(WidgetTester tester, List<Incident> incidents) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [incidentsProvider.overrideWith((ref) async => incidents)],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: const IncidentsListPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // A router that hosts the list page, so the FAB and tile `context.push(...)`
  // calls can be exercised end to end against placeholder destinations.
  GoRouter listRouter() => GoRouter(
    initialLocation: '/incidents',
    routes: [
      GoRoute(
        path: '/incidents',
        builder: (context, state) => const IncidentsListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('NEW FORM'))),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => Scaffold(
              body: Center(child: Text('EDIT ${state.pathParameters['id']}')),
            ),
          ),
        ],
      ),
    ],
  );

  testWidgets('shows the non-punitive empty state', (tester) async {
    await pump(tester, const []);
    expect(find.textContaining('without judgment'), findsOneWidget);
  });

  testWidgets('lists incidents with category and severity', (tester) async {
    await pump(tester, [incident(diveId: 'd1')]);
    expect(find.textContaining('Free-flow at 18 m'), findsOneWidget);
    expect(find.textContaining('Gas supply'), findsOneWidget);
    expect(find.textContaining('Moderate'), findsOneWidget);
    expect(find.textContaining('Linked to a dive'), findsOneWidget);
    // The wall-clock UTC date renders directly (no toLocal), so the shown day
    // is stable regardless of the host timezone.
    expect(find.textContaining('Jul 10, 2026'), findsOneWidget);
  });

  testWidgets('a serious incident renders the highlighted tile icon', (
    tester,
  ) async {
    await pump(tester, [incident(severity: IncidentSeverity.serious)]);

    expect(find.textContaining('Serious'), findsOneWidget);
    // Exercises the serious-severity color branch on the tile leading icon.
    final icon = tester.widget<Icon>(find.byIcon(Icons.flag_outlined));
    expect(icon.color, isNotNull);
  });

  testWidgets('a load error shows a generic localized retry message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incidentsProvider.overrideWith(
            (ref) async => throw Exception('db read failed'),
          ),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: const IncidentsListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Generic localized message, never the raw exception text.
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('db read failed'), findsNothing);
  });

  testWidgets('the add button navigates to the create form', (tester) async {
    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [incidentsProvider.overrideWith((ref) async => const [])],
        router: listRouter(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('NEW FORM'), findsOneWidget);
  });

  testWidgets('tapping an incident opens its detail route', (tester) async {
    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [
          incidentsProvider.overrideWith((ref) async => [incident()]),
        ],
        router: listRouter(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.textContaining('Free-flow at 18 m'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT i1'), findsOneWidget);
  });
}
