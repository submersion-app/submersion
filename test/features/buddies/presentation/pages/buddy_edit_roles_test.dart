import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_roles_editor.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the Professional Roles path on the buddy edit page: loading an
/// existing buddy's credentials, editing them in [BuddyRolesEditor], and
/// persisting on save. Uses a real database so the repository round trip is
/// genuinely exercised (issue #395).
void main() {
  late BuddyRepository buddyRepo;
  late DiverRepository diverRepo;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    buddyRepo = BuddyRepository();
    diverRepo = DiverRepository();

    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    DatabaseService.instance.database; // ensure initialized
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Buddy> seedBuddyWithRole() async {
    final buddy = await buddyRepo.createBuddy(
      Buddy(
        id: '',
        name: 'Alice',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    final now = DateTime(2024);
    await buddyRepo.setRolesForBuddy(buddy.id, [
      BuddyRoleCredential(
        id: '',
        buddyId: buddy.id,
        role: BuddyRole.instructor,
        credentialNumber: 'INS-1',
        agency: CertificationAgency.padi,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    return buddy;
  }

  Widget harness(String buddyId, {void Function(String)? onSaved}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuddyEditPage(
            buddyId: buddyId,
            embedded: true,
            onSaved: onSaved,
          ),
        ),
      ),
    );
  }

  testWidgets('loads and displays an existing buddy\'s professional role', (
    tester,
  ) async {
    final buddy = await seedBuddyWithRole();

    await tester.pumpWidget(harness(buddy.id));
    await tester.pumpAndSettle();

    expect(find.byType(BuddyRolesEditor), findsOneWidget);
    expect(find.text(BuddyRole.instructor.displayName), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'INS-1'), findsOneWidget);
  });

  testWidgets('editing a role credential and saving persists it', (
    tester,
  ) async {
    final buddy = await seedBuddyWithRole();
    String? savedId;

    await tester.pumpWidget(harness(buddy.id, onSaved: (id) => savedId = id));
    await tester.pumpAndSettle();

    // Change the credential number through the editor's field (onChanged).
    await tester.enterText(
      find.widgetWithText(TextFormField, 'INS-1'),
      'INS-2',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    // The save fires async DB writes and then a SnackBar; pump bounded frames
    // (not pumpAndSettle, which the SnackBar timer + list-notifier stream keep
    // busy) until onSaved reports completion.
    for (var i = 0; i < 20 && savedId == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(savedId, buddy.id);
    final roles = await buddyRepo.getRolesForBuddy(buddy.id);
    expect(roles.single.credentialNumber, 'INS-2');

    // Drain the SnackBar timer so the test tears down cleanly.
    await tester.pump(const Duration(seconds: 4));
  });
}
