import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certifications_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The buddy Certifications card's editor (issue #4527, phase 3).
void main() {
  testWidgets('a read that failed says so and offers to try again', (
    tester,
  ) async {
    // No database is open here, so the read fails.
    final session = EditSession(
      Buddy(
        id: 'b1',
        name: 'Alex',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(body: BuddyCertificationsCardEditor(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(buddyCertificationsList.failed(session), isTrue);
    expect(find.byType(SittingLoadFailed), findsOneWidget);
  });

  testWidgets('with none it says so, and Add holds a new certification', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final l = AppLocalizationsEn();
    final session = EditSession(
      Buddy(
        id: 'b1',
        name: 'Alex',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(session.dispose);
    // A new buddy has no certifications to read.
    buddyCertificationsList.loadNone(session);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(body: BuddyCertificationsCardEditor(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.buddies_certifications_empty), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('buddy-cert-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cert-edit-title')),
      'Cavern Diver',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buddy-cert-dialog-done')));
    await tester.pumpAndSettle();

    final held = buddyCertificationsList.current(session)!;
    expect(held, hasLength(1));
    expect(held.single.name, 'Cavern Diver');
    expect(held.single.buddyId, 'b1');
    expect(find.text(l.buddies_certifications_empty), findsNothing);
  });
}
