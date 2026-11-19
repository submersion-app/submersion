import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certifications_sitting.dart';
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
}
