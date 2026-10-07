import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/presentation/pages/certification_agencies_page.dart';
import 'package:submersion/features/certification_agencies/presentation/pages/certification_agency_edit_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #690: Settings > Manage > Certification Agencies and the agency
/// editor.
void main() {
  late AppDatabase db;
  late CustomCertificationRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final (id, name) in [('a', 'Alex'), ('b', 'Blake')]) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        'VALUES (?, ?, 0, 0)',
        [id, name],
      );
    }
    repo = CustomCertificationRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile));

  group('manage page', () {
    testWidgets('lists own, shared and built-in agencies', (tester) async {
      await repo.createAgency(diverId: 'a', name: 'Club A', isShared: false);
      await repo.createAgency(diverId: 'b', name: 'Club B', isShared: true);
      await repo.createAgency(diverId: 'b', name: 'Hidden', isShared: false);
      await pump(tester, const CertificationAgenciesPage());

      expect(find.text('Your agencies'), findsOneWidget);
      expect(find.text('Built-in agencies'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
      expect(
        find.descendant(
          of: rowOf('Club A'),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsOneWidget,
      );
      expect(find.text('Shared by Blake'), findsOneWidget);
      expect(
        find.descendant(
          of: rowOf('Club B'),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: rowOf('ACUC'),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsNothing,
      );
    });

    testWidgets('the Add agency button creates an agency', (tester) async {
      await pump(tester, const CertificationAgenciesPage());
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Club Y');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect((await repo.getAllAgencies()).single.name, 'Club Y');
      expect(find.text('Club Y'), findsOneWidget);
    });

    testWidgets('an unused agency deletes after confirmation', (tester) async {
      await repo.createAgency(diverId: 'a', name: 'Club A', isShared: false);
      await pump(tester, const CertificationAgenciesPage());
      await tester.tap(
        find.descendant(
          of: rowOf('Club A'),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete Club A?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(await repo.getAllAgencies(), isEmpty);
      expect(find.text('Club A'), findsNothing);
    });

    testWidgets('an agency in use is refused with its counts', (tester) async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club A',
        isShared: false,
      );
      await db.customStatement(
        'INSERT INTO certifications (id, diver_id, name, agency, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, 0, 0)',
        ['c1', 'a', 'Card', a.id],
      );
      await pump(tester, const CertificationAgenciesPage());
      await tester.tap(
        find.descendant(
          of: rowOf('Club A'),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      // No "Delete?" first: an agency in use is refused at once.
      expect(find.text('Delete Club A?'), findsNothing);
      expect(find.text('Still in use'), findsOneWidget);
      expect(
        find.text('Used by 1 certification. Change those first.'),
        findsOneWidget,
      );
      expect(await repo.getAllAgencies(), hasLength(1));
    });
  });

  group('agency editor', () {
    testWidgets('a built-in agency shows its ladder read-only and takes new '
        'certifications', (tester) async {
      await pump(tester, const CertificationAgencyEditPage(agencyId: 'padi'));
      expect(
        find.text(
          'Built-in certifications cannot be changed. You can add your own.',
        ),
        findsOneWidget,
      );
      final openWater = tester.widget<ListTile>(rowOf('Open Water').first);
      expect(openWater.enabled, isFalse);

      await tester.tap(find.text('Add certification'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ice Diver');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect((await repo.getAllLevels()).single.agencyId, 'padi');
      expect(
        find.descendant(
          of: rowOf('Ice Diver'),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('TDI shows its own five course categories, not Progression/'
        'Specialties (issue #3072)', (tester) async {
      await pump(tester, const CertificationAgencyEditPage(agencyId: 'tdi'));

      expect(find.text('Open Circuit'), findsOneWidget);
      expect(find.text('Rebreather'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Overhead'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
      expect(find.text('Progression'), findsNothing);
      expect(find.text('Specialties'), findsNothing);

      // TDI's own level names render, not the generic ones TDI used to
      // share with IANTD/PSAI.
      expect(find.text('Nitrox Diver'), findsOneWidget);
      expect(find.text('Trimix Diver'), findsOneWidget);
    });

    testWidgets('another diver\'s shared agency is read-only', (tester) async {
      final b = await repo.createAgency(
        diverId: 'b',
        name: 'Club B',
        isShared: true,
      );
      await pump(tester, CertificationAgencyEditPage(agencyId: b.id));
      expect(find.text('Club B'), findsWidgets);
      expect(find.text('Add certification'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Edit'),
        ),
        findsNothing,
      );
    });

    testWidgets('an own agency offers Edit and lists its custom rungs', (
      tester,
    ) async {
      final a = await repo.createAgency(
        diverId: 'a',
        name: 'Club A',
        isShared: false,
      );
      await repo.createLevel(
        diverId: 'a',
        agencyId: a.id,
        name: 'Club Diver',
        isProgression: true,
        isShared: false,
      );
      await pump(tester, CertificationAgencyEditPage(agencyId: a.id));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Edit'),
        ),
        findsOneWidget,
      );
      expect(find.text('Club Diver'), findsOneWidget);
      expect(find.text('Open Water'), findsNothing);
    });

    testWidgets('reordering custom rungs persists the new order', (
      tester,
    ) async {
      final l1 = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: false,
      );
      final l2 = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Instructor',
        isProgression: true,
        isShared: false,
      );
      await pump(tester, const CertificationAgencyEditPage(agencyId: 'padi'));
      final handle = find.descendant(
        of: rowOf('Ice Instructor'),
        matching: find.byIcon(Icons.drag_handle),
      );
      final from = tester.getCenter(handle);
      final to = tester.getCenter(rowOf('Ice Diver'));
      final gesture = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout);
      final target = Offset(from.dx, to.dy - 30);
      for (var step = 1; step <= 10; step++) {
        await gesture.moveTo(Offset.lerp(from, target, step / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final byId = {for (final l in await repo.getAllLevels()) l.id: l};
      expect(byId[l2.id]!.sortOrder, lessThan(byId[l1.id]!.sortOrder));
    });
  });
}
