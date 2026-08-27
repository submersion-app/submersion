import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/linked_incidents_row.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Incident incident() => Incident(
    id: 'i1',
    occurredAt: DateTime.utc(2026, 7, 10),
    category: IncidentCategory.gasSupply,
    severity: IncidentSeverity.moderate,
    narrative: 'Free-flow at 18 m.',
    createdAt: DateTime.utc(2026, 7, 10),
    updatedAt: DateTime.utc(2026, 7, 10),
    diveId: 'dive-9',
  );

  testWidgets('renders nothing when the dive has no linked incidents', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incidentsForDiveProvider(
            'dive-9',
          ).overrideWith((ref) async => const <Incident>[]),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: const Scaffold(body: LinkedIncidentsRow(diveId: 'dive-9')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('shows a chip and navigates when incidents are linked', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/dive',
      routes: [
        GoRoute(
          path: '/dive',
          builder: (context, state) =>
              const Scaffold(body: LinkedIncidentsRow(diveId: 'dive-9')),
        ),
        GoRoute(
          path: '/incidents',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('INCIDENTS LIST'))),
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        overrides: [
          incidentsForDiveProvider(
            'dive-9',
          ).overrideWith((ref) async => [incident()]),
        ],
        router: router,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ActionChip), findsOneWidget);
    expect(
      find.textContaining('near-miss linked to this dive'),
      findsOneWidget,
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.text('INCIDENTS LIST'), findsOneWidget);
  });
}
