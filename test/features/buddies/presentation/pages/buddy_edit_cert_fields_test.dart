import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository buddyRepo;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    buddyRepo = BuddyRepository();

    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Widget harness({String? buddyId}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BuddyEditPage(buddyId: buddyId, embedded: true)),
      ),
    );
  }

  Finder agencyDropdown() =>
      find.byType(DropdownButtonFormField<CertificationAgency>);
  Finder levelDropdown() =>
      find.byType(DropdownButtonFormField<CertificationLevel>);

  Future<void> selectFromDropdown(
    WidgetTester tester,
    Finder dropdown,
    String optionLabel,
  ) async {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The overlay duplicates the selected item's label; .last hits the menu.
    // Menu items below the fold must be scrolled into view first.
    final item = find.text(optionLabel).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets('agency dropdown appears above level dropdown', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(agencyDropdown()).dy,
      lessThan(tester.getTopLeft(levelDropdown()).dy),
    );
  });

  testWidgets('selecting CMAS agency restricts the level list', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('2★ Diver'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('no agency selected offers the generic level list', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();
    await tester.tap(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Advanced Open Water'), findsOneWidget);
    expect(find.text('2★ Diver'), findsNothing);
  });

  testWidgets('switching agency resets an incompatible level', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await selectFromDropdown(tester, levelDropdown(), 'Advanced Open Water');
    await selectFromDropdown(tester, agencyDropdown(), 'CMAS');

    expect(find.text('Advanced Open Water'), findsNothing);
  });

  testWidgets('merge mode cycles agency and level through candidates', (
    tester,
  ) async {
    final now = DateTime(2024);
    // Same name/email/phone/notes so the certification cycle buttons are the
    // only ones on screen: [agency, level] in tree order (agency renders
    // first since issue #546).
    final survivor = Buddy(
      id: 'b1',
      name: 'Alice',
      certificationAgency: CertificationAgency.padi,
      certificationLevel: CertificationLevel.openWater,
      createdAt: now,
      updatedAt: now,
    );
    final duplicate = Buddy(
      id: 'b2',
      name: 'Alice',
      certificationAgency: CertificationAgency.cmas,
      certificationLevel: CertificationLevel.cmas2StarDiver,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BuddyEditPage(
              mergeBuddies: [survivor, duplicate],
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Survivor's values are pre-selected.
    expect(find.text('PADI'), findsOneWidget);
    expect(find.text('Open Water'), findsOneWidget);

    final cycleButtons = find.byIcon(Icons.sync_alt);
    expect(cycleButtons, findsNWidgets(2));

    // Cycle the agency to the duplicate's CMAS. The level is deliberately
    // NOT reset during merge cycling - the out-of-catalog Open Water stays
    // selectable via the catalog's ensure mechanism.
    await tester.ensureVisible(cycleButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(cycleButtons.first);
    await tester.pumpAndSettle();
    expect(find.text('CMAS'), findsOneWidget);
    expect(find.text('Open Water'), findsOneWidget);

    // Cycle the level to the duplicate's CMAS grade.
    await tester.ensureVisible(cycleButtons.last);
    await tester.pumpAndSettle();
    await tester.tap(cycleButtons.last);
    await tester.pumpAndSettle();
    expect(find.text('2★ Diver'), findsOneWidget);
  });

  testWidgets('existing buddy with out-of-catalog level still renders it', (
    tester,
  ) async {
    final now = DateTime(2024);
    final buddy = await buddyRepo.createBuddy(
      Buddy(
        id: '',
        name: 'Alice',
        certificationAgency: CertificationAgency.cmas,
        certificationLevel: CertificationLevel.advancedOpenWater,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();

    await tester.ensureVisible(levelDropdown());
    await tester.pumpAndSettle();

    expect(find.text('Advanced Open Water'), findsOneWidget);
  });
}
