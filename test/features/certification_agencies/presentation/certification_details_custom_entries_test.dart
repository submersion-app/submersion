import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

/// Issue #690: the certification Details editor (issue #4527, phase 3)
/// offers custom agencies and certifications, creates them in place, and
/// never resets a stored id it cannot name.
void main() {
  late CustomCertificationRepository customRepo;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('a', 'A', 0, 0)",
    );
    customRepo = CustomCertificationRepository();
  });
  tearDown(tearDownTestDatabase);

  /// The Details editor over [cert], a new certification's seed (PADI, no
  /// level) when null.
  Future<EditSession<Certification>> pumpEditor(
    WidgetTester tester, [
    Certification? cert,
  ]) async {
    // Tall enough that every dropdown item is built without scrolling.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final session = EditSession(cert ?? Certification.empty());
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: CertificationDetailsCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Finder agencyField() => find.byKey(const ValueKey('cert-edit-agency-0'));
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
    final session = await pumpEditor(tester);
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
    expect(session.working.agency, agencies.single.id);
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
    final session = await pumpEditor(tester);
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
    expect(session.working.level, level.id);
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

  testWidgets('an unknown stored agency renders and is left as it is', (
    tester,
  ) async {
    const unknown = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';
    final session = await pumpEditor(
      tester,
      Certification(
        id: 'c1',
        diverId: 'a',
        name: 'My card',
        agency: unknown,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );

    expect(
      find.descendant(of: agencyField(), matching: find.text('Unknown agency')),
      findsOneWidget,
    );
    // Opening it does not rewrite the id; a save writes only what changed.
    expect(session.working.agency, unknown);
    expect(session.isDirty, isFalse);
  });
}
