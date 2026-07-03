import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Buddy _makeBuddy(String id, String name) {
  final now = DateTime(2024, 1, 1);
  return Buddy(id: id, name: name, createdAt: now, updatedAt: now);
}

BuddyRoleCredential _makeCredential({
  required String buddyId,
  BuddyRole role = BuddyRole.instructor,
  String? credentialNumber,
  CertificationAgency? agency,
}) {
  final now = DateTime(2024, 1, 1);
  return BuddyRoleCredential(
    id: '$buddyId-${role.name}',
    buddyId: buddyId,
    role: role,
    credentialNumber: credentialNumber,
    agency: agency,
    createdAt: now,
    updatedAt: now,
  );
}

Diver _makeDiver({String name = 'D', bool isDefault = true}) {
  final now = DateTime(2024, 1, 1);
  return Diver(
    id: '',
    name: name,
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late CourseRepository repository;

  final credentialedBuddy = _makeBuddy('buddy-1', 'Alice Instructor');
  final credential = _makeCredential(
    buddyId: 'buddy-1',
    credentialNumber: '999-PADI',
    agency: CertificationAgency.padi,
  );
  final nonCredentialedBuddy = _makeBuddy('buddy-2', 'Bob NoCert');

  setUp(() async {
    await setUpTestDatabase();
    repository = CourseRepository();
    // courses.instructor_id has a foreign key to buddies(id), so real rows
    // must exist even though the picker's own list is driven by the
    // overridden allBuddiesProvider/allBuddyRolesProvider below.
    await BuddyRepository().createBuddy(credentialedBuddy);
    await BuddyRepository().createBuddy(nonCredentialedBuddy);
    // courses.diver_id has a foreign key to divers(id); seed a default diver
    // so validatedCurrentDiverIdProvider resolves to a real row on save.
    await DiverRepository().createDiver(_makeDiver());
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  List<dynamic> buildOverrides(List<dynamic> base) => [
    ...base,
    courseRepositoryProvider.overrideWithValue(repository),
    allBuddiesProvider.overrideWith(
      (ref) async => [credentialedBuddy, nonCredentialedBuddy],
    ),
    allBuddyRolesProvider.overrideWith(
      (ref) async => {
        'buddy-1': [credential],
      },
    ),
  ];

  Widget buildHarness({
    String? courseId,
    required List<dynamic> overrides,
    void Function(String savedId)? onSavedWithId,
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CourseEditPage(
            courseId: courseId,
            embedded: true,
            onSavedWithId: onSavedWithId,
          ),
        ),
      ),
    );
  }

  Future<void> pickInstructorFromDropdown(
    WidgetTester tester,
    String label,
  ) async {
    final dropdown = find.byType(DropdownButtonFormField<String?>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'picking a credentialed buddy fills instructor name and number fields',
    (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        buildHarness(overrides: buildOverrides(overrides)),
      );
      await tester.pumpAndSettle();

      await pickInstructorFromDropdown(
        tester,
        'Alice Instructor (${credential.displayLabel})',
      );

      expect(
        find.widgetWithText(TextFormField, 'Alice Instructor'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, '999-PADI'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to a non-credentialed buddy clears the instructor number',
    (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        buildHarness(overrides: buildOverrides(overrides)),
      );
      await tester.pumpAndSettle();

      await pickInstructorFromDropdown(
        tester,
        'Alice Instructor (${credential.displayLabel})',
      );
      expect(find.widgetWithText(TextFormField, '999-PADI'), findsOneWidget);

      // Switch to the buddy with no credential: the stale number must clear.
      await pickInstructorFromDropdown(tester, 'Bob NoCert');
      expect(find.widgetWithText(TextFormField, '999-PADI'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Bob NoCert'), findsOneWidget);
    },
  );

  testWidgets(
    'a buddy with no credential still appears in the instructor dropdown',
    (tester) async {
      // Regression: the old inline dropdown filtered on
      // `certificationLevel != null`, so a buddy with no cert level at all
      // (and no instructor credential) never showed up. The shared picker
      // lists every buddy.
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        buildHarness(overrides: buildOverrides(overrides)),
      );
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String?>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('Bob NoCert').last, findsOneWidget);
    },
  );

  testWidgets('saving persists instructorId through to the repository', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    String? savedId;

    await tester.pumpWidget(
      buildHarness(
        overrides: buildOverrides(overrides),
        onSavedWithId: (id) => savedId = id,
      ),
    );
    await tester.pumpAndSettle();

    // Enter the course name before scrolling down to the instructor picker
    // -- the name field sits above the picker in the ListView and can fall
    // outside the sliver cache extent (and thus out of the widget tree)
    // once the list scrolls past it.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Advanced Open Water',
    );
    await tester.pumpAndSettle();

    await pickInstructorFromDropdown(
      tester,
      'Alice Instructor (${credential.displayLabel})',
    );

    final saveButton = find.widgetWithText(TextButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(savedId, isNotNull);
    final saved = await repository.getCourseById(savedId!);
    expect(saved?.instructorId, 'buddy-1');
  });
}
