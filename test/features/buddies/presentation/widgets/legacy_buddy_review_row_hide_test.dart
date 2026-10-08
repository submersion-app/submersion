import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_row.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The legacy buddy review row's role dropdown narrows to visible roles
/// (issue #401) but keeps the row's own role.
void main() {
  final now = DateTime(2026);
  DiveRole builtIn(String id, String name) => DiveRole(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: now,
    updatedAt: now,
  );
  final roles = [
    builtIn(DiveRole.buddyId, 'Buddy'),
    builtIn(DiveRole.instructorId, 'Instructor'),
    builtIn(DiveRole.soloId, 'Solo'),
  ];

  Future<void> pump(
    WidgetTester tester,
    String roleId, {
    Set<String> keepRoleIds = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LegacyBuddyReviewRow(
            link: PlannedLink(
              target: const NewBuddyTarget('Ann'),
              roleId: roleId,
            ),
            roles: roles,
            hiddenRoleIds: {DiveRole.soloId, DiveRole.instructorId},
            keepRoleIds: keepRoleIds,
            onRoleChanged: (_) {},
            onUseSuggestion: () {},
            onEditName: () {},
            onChooseExisting: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legacy-row-role-new:ann')));
    await tester.pumpAndSettle();
  }

  testWidgets('hidden roles leave the dropdown', (tester) async {
    await pump(tester, DiveRole.buddyId);
    expect(find.text('Solo'), findsNothing);
    expect(find.text('Instructor'), findsNothing);
  });

  testWidgets("the row's own hidden role stays, by its real name", (
    tester,
  ) async {
    await pump(tester, DiveRole.instructorId);
    expect(find.text('Instructor'), findsWidgets);
    expect(find.text('Solo'), findsNothing);
  });

  testWidgets('the role the planner chose stays after it is changed', (
    tester,
  ) async {
    await pump(tester, DiveRole.buddyId, keepRoleIds: {DiveRole.instructorId});
    expect(find.text('Instructor'), findsWidgets);
    expect(find.text('Solo'), findsNothing);
  });
}
