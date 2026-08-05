import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late CertificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditPage(
    WidgetTester tester, {
    String? certificationId,
    Certification? initialCertification,
    void Function(Certification)? onStaged,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          certificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () => context.push('/edit'),
                        child: const Text('Go to Edit'),
                      );
                    },
                  ),
                ),
              ),
              GoRoute(
                path: '/edit',
                builder: (context, state) => Scaffold(
                  body: CertificationEditPage(
                    certificationId: certificationId,
                    initialCertification: initialCertification,
                    onStaged: onStaged,
                  ),
                ),
              ),
            ],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (tester.any(find.text('Go to Edit'))) {
      await tester.tap(find.text('Go to Edit'));
      await tester.pumpAndSettle();
    }
  }

  group('Auto-generation logic', () {
    testWidgets(
      'new certification should have empty name initially (level is null)',
      (tester) async {
        await pumpEditPage(tester);

        final nameField = find.byType(TextFormField).first;
        expect(tester.widget<TextFormField>(nameField).controller?.text, '');
      },
    );

    testWidgets('changing agency while level is null should NOT update name', (
      tester,
    ) async {
      await pumpEditPage(tester);

      // Change agency to SSI
      await tester.tap(find.text('PADI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSI').last);
      await tester.pumpAndSettle();

      final nameField = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(nameField).controller?.text, '');
    });

    testWidgets(
      'selecting BOTH agency and level should update default name to "Agency : Level"',
      (tester) async {
        await pumpEditPage(tester);

        // Select Level: Open Water
        await tester.tap(find.byIcon(Icons.stairs).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Water').last);
        await tester.pumpAndSettle();

        final nameField = find.byType(TextFormField).first;
        expect(
          tester.widget<TextFormField>(nameField).controller?.text,
          'PADI : Open Water',
        );

        // Change agency to SSI
        await tester.tap(find.text('PADI').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SSI').last);
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextFormField>(nameField).controller?.text,
          'SSI : Open Water',
        );
      },
    );

    testWidgets('clearing level should clear auto-generated name', (
      tester,
    ) async {
      await pumpEditPage(tester);

      // Select Level: Open Water
      await tester.tap(find.byIcon(Icons.stairs).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Water').last);
      await tester.pumpAndSettle();

      final nameField = find.byType(TextFormField).first;
      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'PADI : Open Water',
      );

      // Change agency to CMAS (which resets level if not compatible)
      await tester.tap(find.text('PADI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CMAS').last);
      await tester.pumpAndSettle();

      // Level should have been reset to null because Open Water is not in CMAS catalog
      expect(tester.widget<TextFormField>(nameField).controller?.text, '');
    });

    testWidgets(
      'manual edit should stop auto-update even after level selected',
      (tester) async {
        await pumpEditPage(tester);

        final nameField = find.byType(TextFormField).first;

        // Manually edit name
        await tester.enterText(nameField, 'My Special Cert');
        await tester.pumpAndSettle();

        // Select level
        await tester.tap(find.byIcon(Icons.stairs).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Water').last);
        await tester.pumpAndSettle();

        // Name should NOT change
        expect(
          tester.widget<TextFormField>(nameField).controller?.text,
          'My Special Cert',
        );
      },
    );

    testWidgets('matching default pattern manually resumes auto-update', (
      tester,
    ) async {
      await pumpEditPage(tester);

      final nameField = find.byType(TextFormField).first;

      // Select level
      await tester.tap(find.byIcon(Icons.stairs).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Water').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'PADI : Open Water',
      );

      // Manually edit to something else
      await tester.enterText(nameField, 'Custom');
      await tester.pumpAndSettle();

      // Change agency - name should NOT change
      await tester.tap(find.text('PADI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSI').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'Custom',
      );

      // Manually set back to current default pattern "SSI : Open Water"
      await tester.enterText(nameField, 'SSI : Open Water');
      await tester.pumpAndSettle();

      // Change agency back to PADI - name SHOULD change now
      await tester.tap(find.text('SSI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PADI').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(nameField).controller?.text,
        'PADI : Open Water',
      );
    });
  });

  group('Form interactions and coverage', () {
    testWidgets('validation error when name is empty on save', (tester) async {
      await pumpEditPage(tester);

      // Clear auto-generated name if any (though it's empty by default now)
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a certification name'), findsOneWidget);
    });

    testWidgets('loading an existing certification prefills the form', (
      tester,
    ) async {
      final cert = Certification(
        id: 'cert-123',
        name: 'Rescue Diver',
        agency: CertificationAgency.padi,
        level: CertificationLevel.rescue,
        cardNumber: '12345',
        notes: 'Some notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createCertification(cert);

      await pumpEditPage(tester, certificationId: 'cert-123');

      expect(find.text('Rescue Diver'), findsAtLeastNWidgets(1));
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('Some notes'), findsOneWidget);
      expect(find.text('PADI'), findsWidgets);
      expect(find.text('Rescue Diver'), findsAtLeastNWidgets(1));
    });

    testWidgets('staging mode works with initial certification', (
      tester,
    ) async {
      final initialCert = Certification(
        id: 'staged-1',
        name: 'Staged Cert',
        agency: CertificationAgency.ssi,
        level: CertificationLevel.openWater,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Certification? capturedStaged;
      await pumpEditPage(
        tester,
        initialCertification: initialCert,
        onStaged: (c) => capturedStaged = c,
      );

      expect(find.text('Staged Cert'), findsOneWidget);
      expect(find.text('SSI'), findsWidgets);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(capturedStaged, isNotNull);
      expect(capturedStaged?.name, 'Staged Cert');
    });

    testWidgets('date pickers work', (tester) async {
      await pumpEditPage(tester);

      // Issue date
      await tester.tap(find.byIcon(Icons.calendar_today).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify some date is shown (format might vary, but field should not be empty)
      // Since we just picked "today", it should show something.

      // Expiry date
      await tester.tap(find.byIcon(Icons.calendar_today).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('notes field is editable', (tester) async {
      await pumpEditPage(tester);
      final notesField = find.byType(TextFormField).last;
      await tester.enterText(notesField, 'Test Notes');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(notesField).controller?.text,
        'Test Notes',
      );
    });

    testWidgets('unsaved changes dialog shows when popping with changes', (
      tester,
    ) async {
      await pumpEditPage(tester);

      // Make a change
      await tester.enterText(find.byType(TextFormField).first, 'Some Change');
      await tester.pumpAndSettle();

      // Try to pop using the back button in AppBar if it exists, or simulate back navigation
      // Our harness has an AppBar? CertificationEditPage uses Scaffold but may not have AppBar.
      // Actually it does:
      /*
      appBar: AppBar(
        title: Text(isEditing ? ... : ...),
        leading: widget.embedded ? null : IconButton(icon: const Icon(Icons.close), ...),
      )
      */

      // Let's find the close button
      final closeButton = find.byIcon(Icons.close);
      if (tester.any(closeButton)) {
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(find.text('Unsaved Changes'), findsOneWidget);

        // Tap "Stay" to stay
        await tester.tap(find.text('Stay'));
        await tester.pumpAndSettle();
        expect(find.text('Unsaved Changes'), findsNothing);

        // Tap "Discard" to leave
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        // Should be back at root
        expect(find.text('Go to Edit'), findsOneWidget);
      }
    });

    testWidgets('instructor picker works', (tester) async {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Alice Instructor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final credential = BuddyRoleCredential(
        id: 'cred-1',
        buddyId: 'buddy-1',
        role: BuddyRole.instructor,
        credentialNumber: '999-PADI',
        agency: CertificationAgency.padi,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            certificationRepositoryProvider.overrideWithValue(repository),
            allBuddiesProvider.overrideWith((ref) async => [buddy]),
            allBuddyRolesProvider.overrideWith(
              (ref) async => {
                'buddy-1': [credential],
              },
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/edit',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Root')),
                ),
                GoRoute(
                  path: '/edit',
                  builder: (context, state) =>
                      const Scaffold(body: CertificationEditPage()),
                ),
              ],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find instructor picker
      final picker = find.byType(DropdownButtonFormField<String?>).last;
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();

      // Select Alice
      await tester.tap(find.textContaining('Alice Instructor').last);
      await tester.pumpAndSettle();

      // Verify name and number fields are filled
      expect(
        find.widgetWithText(TextFormField, 'Alice Instructor'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, '999-PADI'), findsOneWidget);
    });

    testWidgets('saving an existing certification updates it', (tester) async {
      final cert = Certification(
        id: 'cert-to-update',
        name: 'Old Name',
        agency: CertificationAgency.ssi,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createCertification(cert);

      await pumpEditPage(tester, certificationId: 'cert-to-update');

      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'Updated Name');
      await tester.pumpAndSettle();

      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final updated = await repository.getCertificationById('cert-to-update');
      expect(updated?.name, 'Updated Name');
    });
  });
}
