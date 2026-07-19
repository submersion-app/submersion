import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/pages/incident_edit_page.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// Loads a fixed result (or throws) for `getIncidentById`, so the edit page's
/// load path can be exercised without a database.
class _FakeIncidentRepository extends IncidentRepository {
  _FakeIncidentRepository({this.result, this.error});

  final Incident? result;
  final Object? error;

  @override
  Future<Incident?> getIncidentById(String id) async {
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  Future<void> pumpEdit(
    WidgetTester tester,
    _FakeIncidentRepository repo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [incidentRepositoryProvider.overrideWithValue(repo)],
        child: localizedMaterialApp(
          home: const IncidentEditPage(incidentId: 'missing'),
        ),
      ),
    );
    await tester.pump(); // resolve the getIncidentById future
    await tester.pump();
  }

  testWidgets('missing record shows not-found, never the create form', (
    tester,
  ) async {
    await pumpEdit(tester, _FakeIncidentRepository(result: null));

    // Not-found copy is shown and the editable form (Save button) is not, so
    // Save can never silently create a new record under an "Edit" title.
    expect(find.text('Near-miss report not found'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('read error surfaces a message instead of a stuck spinner', (
    tester,
  ) async {
    await pumpEdit(
      tester,
      _FakeIncidentRepository(error: Exception('db read failed')),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
  });
}
