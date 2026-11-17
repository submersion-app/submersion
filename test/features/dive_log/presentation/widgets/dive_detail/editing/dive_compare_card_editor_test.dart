import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_compare_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_plan_link_sitting.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/l10n_test_helpers.dart';

/// The Compare card's editor waits for the dive's linked plan, and says so
/// when it cannot be read (issue #4527, plan 6).
void main() {
  final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));

  Future<EditSession<Dive>> pump(WidgetTester tester, _Plans plans) async {
    final container = ProviderContainer(
      overrides: [divePlanRepositoryProvider.overrideWithValue(plans)],
    );
    addTearDown(container.dispose);
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    loadDivePlanLink(session, container.read);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(body: DiveCompareCardEditor(session: session)),
        ),
      ),
    );
    return session;
  }

  testWidgets('opened before the link is read, it draws once it is', (
    tester,
  ) async {
    final plans = _Plans()..gate = Completer<void>();
    await pump(tester, plans);
    expect(find.text('Link a plan'), findsNothing);

    plans.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Link a plan'), findsOneWidget);
  });

  testWidgets('a read that fails says so, and Try again reads it', (
    tester,
  ) async {
    final plans = _Plans()..failing = true;
    await pump(tester, plans);
    await tester.pump();
    await tester.pump();
    expect(find.text('This card could not be loaded.'), findsOneWidget);

    plans.failing = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('This card could not be loaded.'), findsNothing);
    expect(find.text('Link a plan'), findsOneWidget);
  });
}

class _Plans extends DivePlanRepository {
  bool failing = false;
  Completer<void>? gate;

  @override
  Future<domain.DivePlan?> getPlanByLinkedDiveId(String diveId) async {
    await gate?.future;
    if (failing) throw StateError('database locked');
    return null;
  }
}
