import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #690: the certification editor offers custom agencies and
/// certifications, creates them in place, and never resets a stored id it
/// cannot name.
void main() {
  late AppDatabase db;
  late CertificationRepository certRepo;
  late CustomCertificationRepository customRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('a', 'A', 0, 0)",
    );
    certRepo = CertificationRepository();
    customRepo = CustomCertificationRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? certificationId,
  }) async {
    // Tall enough that every dropdown item is built without scrolling.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          certificationRepositoryProvider.overrideWithValue(certRepo),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CertificationEditPage(
              certificationId: certificationId,
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder agencyField() => find.byKey(const ValueKey('cred-agency-0'));
  Finder levelField() =>
      find.byType(DropdownButtonFormField<CertificationOption>);

  Future<void> openAndTap(
    WidgetTester tester,
    Finder field,
    String label,
  ) async {
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('custom agencies appear before Other, with an add action', (
    tester,
  ) async {
    await customRepo.createAgency(
      diverId: 'a',
      name: 'Club X',
      isShared: false,
    );
    await pumpEditor(tester);
    await tester.tap(agencyField());
    await tester.pumpAndSettle();
    expect(find.text('Club X'), findsWidgets);
    expect(find.text('Add custom agency...'), findsOneWidget);
    final clubY = tester.getTopLeft(find.text('Club X').last).dy;
    final other = tester.getTopLeft(find.text('Other').last).dy;
    expect(clubY, lessThan(other));
  });

  testWidgets('Add custom agency creates and selects the new agency', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openAndTap(tester, agencyField(), 'Add custom agency...');
    await tester.enterText(find.byType(TextField).last, 'Club Y');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final agencies = await customRepo.getAllAgencies();
    expect(agencies.single.name, 'Club Y');
    expect(agencies.single.diverId, 'a');
    expect(
      find.descendant(of: agencyField(), matching: find.text('Club Y')),
      findsOneWidget,
    );
  });

  testWidgets('a quick-created agency clears a built-in level', (tester) async {
    await pumpEditor(tester);
    await openAndTap(tester, levelField(), 'Open Water');
    expect(
      find.descendant(of: levelField(), matching: find.text('Open Water')),
      findsOneWidget,
    );
    await openAndTap(tester, agencyField(), 'Add custom agency...');
    await tester.enterText(find.byType(TextField).last, 'Club Z');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: levelField(), matching: find.text('Open Water')),
      findsNothing,
      reason: 'a custom agency has no built-in rungs',
    );
  });

  testWidgets('Add custom certification creates a ranked rung under PADI', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openAndTap(tester, levelField(), 'Add custom certification...');
    await tester.enterText(find.byType(TextField).last, 'Ice Diver');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final level = (await customRepo.getAllLevels()).single;
    expect(level.name, 'Ice Diver');
    expect(level.agencyId, 'padi');
    expect(level.isProgression, isTrue);
    expect(
      find.descendant(of: levelField(), matching: find.text('Ice Diver')),
      findsOneWidget,
    );
  });

  testWidgets('a duplicate name keeps the dialog open with an error', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openAndTap(tester, agencyField(), 'Add custom agency...');
    await tester.enterText(find.byType(TextField).last, 'PADI');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(find.text('That name is already in use'), findsOneWidget);
    expect(await customRepo.getAllAgencies(), isEmpty);
  });

  testWidgets('an unknown stored agency renders and survives a save', (
    tester,
  ) async {
    const unknown = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';
    await db.customStatement(
      'INSERT INTO certifications (id, diver_id, name, agency, created_at, '
      'updated_at) VALUES (?, ?, ?, ?, 0, 0)',
      ['c1', 'a', 'My card', unknown],
    );
    await pumpEditor(tester, certificationId: 'c1');
    expect(
      find.descendant(of: agencyField(), matching: find.text('Unknown agency')),
      findsOneWidget,
    );
    await tester.tap(find.text('Save').first);
    await tester.pump(const Duration(seconds: 1));
    final row = await tester.runAsync(
      () => (db.select(
        db.certifications,
      )..where((t) => t.id.equals('c1'))).getSingle(),
    );
    expect(row!.agency, unknown);
    expect(row.updatedAt, isNot(0), reason: 'the save actually ran');
  });
}
