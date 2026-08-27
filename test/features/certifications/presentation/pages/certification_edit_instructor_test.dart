import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Buddy _makeBuddy(String id, String name) {
  final now = DateTime(2024, 1, 1);
  return Buddy(id: id, name: name, createdAt: now, updatedAt: now);
}

Certification _makeInstructorCert({
  required String buddyId,
  String? cardNumber,
  CertificationAgency agency = CertificationAgency.padi,
}) {
  final now = DateTime(2024, 1, 1);
  return Certification(
    id: '$buddyId-instructor',
    buddyId: buddyId,
    name: 'Instructor',
    agency: agency,
    level: CertificationLevel.instructor,
    cardNumber: cardNumber,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late CertificationRepository repository;

  final credentialedBuddy = _makeBuddy('buddy-1', 'Alice Instructor');
  final instructorCert = _makeInstructorCert(
    buddyId: 'buddy-1',
    cardNumber: '999-PADI',
    agency: CertificationAgency.padi,
  );
  const instructorLabel = 'PADI Instructor #999-PADI';

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
    // certifications.instructor_id has a foreign key to buddies(id), so a
    // real row must exist even though the picker's own list is driven by
    // the overridden allBuddiesProvider/allBuddyCertificationsProvider below.
    await BuddyRepository().createBuddy(credentialedBuddy);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  List<dynamic> buildOverrides(List<dynamic> base) => [
    ...base,
    certificationRepositoryProvider.overrideWithValue(repository),
    allBuddiesProvider.overrideWith((ref) async => [credentialedBuddy]),
    allBuddyCertificationsProvider.overrideWith(
      (ref) async => {
        'buddy-1': [instructorCert],
      },
    ),
  ];

  Widget buildHarness({
    String? certificationId,
    required List<dynamic> overrides,
    void Function(String savedId)? onSaved,
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CertificationEditPage(
            certificationId: certificationId,
            embedded: true,
            onSaved: onSaved,
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
        'Alice Instructor ($instructorLabel)',
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
      final plainBuddy = _makeBuddy('buddy-2', 'Bob Plain');
      final overrides = [
        ...await getBaseOverrides(),
        certificationRepositoryProvider.overrideWithValue(repository),
        allBuddiesProvider.overrideWith(
          (ref) async => [credentialedBuddy, plainBuddy],
        ),
        allBuddyCertificationsProvider.overrideWith(
          (ref) async => {
            'buddy-1': [instructorCert],
          },
        ),
      ];

      await tester.pumpWidget(buildHarness(overrides: overrides));
      await tester.pumpAndSettle();

      // Pick the credentialed buddy first: number fills.
      await pickInstructorFromDropdown(
        tester,
        'Alice Instructor ($instructorLabel)',
      );
      expect(find.widgetWithText(TextFormField, '999-PADI'), findsOneWidget);

      // Switch to the buddy with no credential: the stale number must clear.
      await pickInstructorFromDropdown(tester, 'Bob Plain');
      expect(find.widgetWithText(TextFormField, '999-PADI'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Bob Plain'), findsOneWidget);
    },
  );

  testWidgets(
    'editing the name text after picking does not clear the selection',
    (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        buildHarness(overrides: buildOverrides(overrides)),
      );
      await tester.pumpAndSettle();

      await pickInstructorFromDropdown(
        tester,
        'Alice Instructor ($instructorLabel)',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Alice Instructor'),
        'Alice I. Edited',
      );
      await tester.pumpAndSettle();

      // The dropdown still shows the selected instructor -- editing the name
      // text field does not clear _instructorId.
      expect(find.text('Alice Instructor ($instructorLabel)'), findsOneWidget);
    },
  );

  testWidgets('selecting None keeps the text fields contents', (tester) async {
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(buildHarness(overrides: buildOverrides(overrides)));
    await tester.pumpAndSettle();

    await pickInstructorFromDropdown(
      tester,
      'Alice Instructor ($instructorLabel)',
    );
    await pickInstructorFromDropdown(tester, 'None (manual entry)');

    expect(
      find.widgetWithText(TextFormField, 'Alice Instructor'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '999-PADI'), findsOneWidget);
  });

  testWidgets('saving passes instructorId through to the repository', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    String? savedId;

    await tester.pumpWidget(
      buildHarness(
        overrides: buildOverrides(overrides),
        onSaved: (id) => savedId = id,
      ),
    );
    await tester.pumpAndSettle();

    await pickInstructorFromDropdown(
      tester,
      'Alice Instructor ($instructorLabel)',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name on card'),
      'Open Water Diver',
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Add Certification');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(savedId, isNotNull);
    final saved = await repository.getCertificationById(savedId!);
    expect(saved?.instructorId, 'buddy-1');
  });

  testWidgets(
    'loading an existing cert with instructorId pre-selects the dropdown',
    (tester) async {
      final now = DateTime(2024, 1, 1);
      final existing = await repository.createCertification(
        Certification(
          id: '',
          name: 'Advanced Open Water',
          agency: CertificationAgency.padi,
          instructorId: 'buddy-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        buildHarness(
          certificationId: existing.id,
          overrides: buildOverrides(overrides),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Instructor ($instructorLabel)'), findsOneWidget);
    },
  );
}
