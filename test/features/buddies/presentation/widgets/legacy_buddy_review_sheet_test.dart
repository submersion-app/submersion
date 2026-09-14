import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _epoch = DateTime.utc(2026);
final _l10n = lookupAppLocalizations(const Locale('en'));

final _roles = [
  DiveRole(
    id: DiveRole.buddyId,
    name: 'Buddy',
    isBuiltIn: true,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  DiveRole(
    id: DiveRole.instructorId,
    name: 'Instructor',
    isBuiltIn: true,
    sortOrder: 2,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  DiveRole(
    id: DiveRole.diveMasterId,
    name: 'Dive Master',
    isBuiltIn: true,
    sortOrder: 4,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
];

final _matcher = BuddyNameMatcher([
  MatchCandidate(
    id: 'jim',
    name: 'Jim Dunfield',
    diverId: 'me',
    createdAt: _epoch,
  ),
  MatchCandidate(
    id: 'leo',
    name: 'Leo Cox',
    diverId: 'me',
    diveCount: 3,
    createdAt: _epoch,
  ),
], diverId: 'me');

ConversionPlan _plan() => planLegacyConversion(
  diveId: 'd1',
  buddyText: 'Jim Dunfield, Leo',
  diveMasterText: 'Ana',
  matcher: _matcher,
);

/// Opens the sheet from a button and returns the list its result lands in.
Future<List<ConversionPlan?>> _open(
  WidgetTester tester, [
  ConversionPlan? plan,
]) async {
  final results = <ConversionPlan?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [allDiveRolesProvider.overrideWith((ref) async => _roles)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showLegacyBuddyReviewSheet(
                  context,
                  plan: plan ?? _plan(),
                  matcher: _matcher,
                ),
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
  return results;
}

Future<void> _tapLink(WidgetTester tester, int count) async {
  await tester.tap(find.text(_l10n.buddies_linkText_linkCount(count)));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String identity, String item) async {
  await tester.tap(find.byKey(Key('legacy-row-menu-$identity')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows each parsed name with its status and source', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text(_l10n.buddies_linkText_sheetTitle), findsOneWidget);
    expect(
      find.text(_l10n.buddies_linkText_sourceBuddy('Jim Dunfield, Leo')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.buddies_linkText_sourceDiveMaster('Ana')),
      findsOneWidget,
    );
    expect(find.text('Jim Dunfield'), findsOneWidget);
    expect(find.text(_l10n.buddies_linkText_statusExisting), findsOneWidget);
    expect(find.text(_l10n.buddies_linkText_statusNew), findsNWidgets(2));
    expect(
      find.text(_l10n.buddies_linkText_suggestion('Leo Cox')),
      findsOneWidget,
    );
  });

  testWidgets('Link returns the reviewed plan', (tester) async {
    final results = await _open(tester);

    await _tapLink(tester, 3);

    expect(results.single, _plan());
  });

  testWidgets('Cancel returns null', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text(_l10n.common_action_cancel));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('Use applies the suggestion', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text(_l10n.buddies_linkText_useSuggestion));
    await tester.pumpAndSettle();
    await _tapLink(tester, 3);

    final leo = results.single!.links[1];
    expect(
      leo.target,
      const ExistingBuddyTarget(buddyId: 'leo', name: 'Leo Cox'),
    );
    expect(leo.suggestion, isNull);
  });

  testWidgets('Remove drops a row', (tester) async {
    final results = await _open(tester);

    await _menu(tester, 'new:ana', _l10n.common_action_remove);
    await _tapLink(tester, 2);

    expect(results.single!.links.map((l) => l.name), ['Jim Dunfield', 'Leo']);
  });

  testWidgets('Edit name re-matches the row', (tester) async {
    final results = await _open(tester);

    await _menu(tester, 'new:leo', _l10n.buddies_linkText_editName);
    await tester.enterText(find.byType(TextField), 'leo cox');
    await tester.tap(find.text(_l10n.common_action_save));
    await tester.pumpAndSettle();
    await _tapLink(tester, 3);

    expect(
      results.single!.links[1].target,
      const ExistingBuddyTarget(buddyId: 'leo', name: 'Leo Cox'),
    );
  });

  testWidgets('Choose existing re-points a row and merges duplicates', (
    tester,
  ) async {
    final results = await _open(tester);

    await _menu(tester, 'new:ana', _l10n.buddies_linkText_chooseExisting);
    await tester.tap(
      find.descendant(
        of: find.byType(BuddyCandidatePickerSheet),
        matching: find.text('Jim Dunfield'),
      ),
    );
    await tester.pumpAndSettle();
    await _tapLink(tester, 2);

    final links = results.single!.links;
    expect(
      links.first.target,
      const ExistingBuddyTarget(buddyId: 'jim', name: 'Jim Dunfield'),
    );
    expect(links.first.roleId, DiveRole.diveMasterId);
    expect(links.last.name, 'Leo');
  });

  testWidgets('the role dropdown changes a row role', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.byKey(const Key('legacy-row-role-id:jim')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.diveRole_builtin_instructor).last);
    await tester.pumpAndSettle();
    await _tapLink(tester, 3);

    expect(results.single!.links.first.roleId, DiveRole.instructorId);
  });

  testWidgets('Add a name appends a new buddy row', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text(_l10n.buddies_linkText_addName));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zoe');
    await tester.tap(find.text(_l10n.common_action_save));
    await tester.pumpAndSettle();
    await _tapLink(tester, 4);

    final zoe = results.single!.links.last;
    expect(zoe.target, const NewBuddyTarget('Zoe'));
    expect(zoe.roleId, DiveRole.buddyId);
  });

  testWidgets('warns when several buddies share the matched name', (
    tester,
  ) async {
    final namesakes = BuddyNameMatcher([
      MatchCandidate(
        id: 'a',
        name: 'Jack Evans',
        diverId: 'me',
        createdAt: _epoch,
      ),
      MatchCandidate(
        id: 'b',
        name: 'Jack Evans',
        diverId: 'me',
        createdAt: _epoch,
      ),
    ], diverId: 'me');
    await _open(
      tester,
      planLegacyConversion(
        diveId: 'd1',
        buddyText: 'Jack Evans',
        matcher: namesakes,
      ),
    );

    expect(
      find.text(_l10n.buddies_linkText_tie(2, 'Jack Evans')),
      findsOneWidget,
    );
  });

  testWidgets('Link is disabled once every row is removed', (tester) async {
    await _open(
      tester,
      planLegacyConversion(diveId: 'd1', buddyText: 'Ann', matcher: _matcher),
    );

    await _menu(tester, 'new:ann', _l10n.common_action_remove);

    final link = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, _l10n.buddies_linkText_linkCount(0)),
    );
    expect(link.onPressed, isNull);
  });
}
