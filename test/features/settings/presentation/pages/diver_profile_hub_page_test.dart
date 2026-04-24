import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_hub_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _MockDiverListNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  DeleteDiverResult deleteResult = const DeleteDiverResult(
    reassignedTripsCount: 0,
    reassignedSitesCount: 0,
  );

  int deleteCalls = 0;

  @override
  Future<void> refresh() async {}

  @override
  Future<Diver> addDiver(Diver diver) async => diver;

  @override
  Future<void> updateDiver(Diver diver) async {}

  @override
  Future<DeleteDiverResult> deleteDiver(String id) async {
    deleteCalls++;
    return deleteResult;
  }

  @override
  Future<void> setAsDefault(String id) async {}
}

void main() {
  final now = DateTime.now();

  Diver makeDiver({
    String id = 'diver-1',
    String name = 'Alice Alpha',
    String? email,
    String? phone,
    String? bloodType,
    DiverInsurance insurance = const DiverInsurance(),
    String notes = '',
    EmergencyContact emergency = const EmergencyContact(),
  }) {
    return Diver(
      id: id,
      name: name,
      email: email,
      phone: phone,
      bloodType: bloodType,
      emergencyContact: emergency,
      insurance: insurance,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('DiverProfileHubPage loading/error/no-diver states', () {
    testWidgets('shows loading indicator while current diver is loading', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith(
              (_) => Future.delayed(const Duration(seconds: 10), () => null),
            ),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows error state when current diver load fails', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith(
              (_) => Future.error(Exception('hub-boom')),
            ),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error'), findsWidgets);
    });

    testWidgets('shows no-diver state with add button when diver is null', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => null),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_add), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('DiverProfileHubPage with active diver', () {
    testWidgets('renders active diver card, section tiles, and management', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver(
        email: 'a@b.com',
        phone: '+1111',
        bloodType: 'O+',
        notes: 'Loves diving',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Active diver card.
      expect(find.text('Alice Alpha'), findsWidgets);
      expect(find.text('Active Diver'), findsOneWidget);
      // Section tiles present (scroll to find them).
      await tester.scrollUntilVisible(
        find.byIcon(Icons.swap_horiz),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.contact_phone), findsOneWidget);
      expect(find.byIcon(Icons.medical_information), findsOneWidget);
      expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsOneWidget);
      // Management tiles.
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
      // Subtitle for personal info = email.
      expect(find.text('a@b.com'), findsOneWidget);
      // Subtitle for medical info = blood type.
      expect(find.text('O+'), findsOneWidget);
      // Subtitle for notes = first line of notes.
      expect(find.text('Loves diving'), findsOneWidget);
    });

    testWidgets('shows delete option when multiple divers exist', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final d1 = makeDiver(id: 'd1', name: 'Diver One');
      final d2 = makeDiver(id: 'd2', name: 'Diver Two');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => d1),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([d1, d2]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Delete Diver'), findsOneWidget);
    });

    testWidgets('hides delete option when only one diver exists', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('renders phone subtitle when email is missing', (tester) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver(phone: '+5555');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+5555'), findsOneWidget);
    });

    testWidgets('renders name subtitle when no email/phone', (tester) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver(name: 'Solo Diver');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Name appears in both card and subtitle.
      expect(find.text('Solo Diver'), findsWidgets);
    });

    testWidgets('renders insurance subtitle when provider set', (tester) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver(
        insurance: DiverInsurance(
          provider: 'DAN',
          expiryDate: DateTime.now().add(const Duration(days: 180)),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DAN'), findsOneWidget);
    });

    testWidgets('renders expired insurance subtitle', (tester) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver(
        insurance: DiverInsurance(
          provider: 'DAN',
          expiryDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Expired'), findsOneWidget);
    });
  });

  group('DiverProfileHubPage navigation', () {
    testWidgets('tapping Personal Info tile navigates to route', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      final router = GoRouter(
        initialLocation: '/hub',
        routes: [
          GoRoute(
            path: '/hub',
            builder: (context, state) => const DiverProfileHubPage(),
          ),
          GoRoute(
            path: '/settings/diver-profile/personal',
            builder: (context, state) =>
                const Scaffold(body: Text('PERSONAL_PAGE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => diver),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([diver]),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(find.text('PERSONAL_PAGE'), findsOneWidget);
    });

    testWidgets('tapping Switch Diver opens bottom sheet', (tester) async {
      final overrides = await getBaseOverrides();
      final d1 = makeDiver(id: 'd1', name: 'Diver One');
      final d2 = makeDiver(id: 'd2', name: 'Diver Two');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => d1),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([d1, d2]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(Icons.swap_horiz),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      // Switcher shows both divers.
      expect(find.textContaining('Switch'), findsWidgets);
      // Both diver names should show in sheet.
      expect(find.text('Diver One'), findsWidgets);
      expect(find.text('Diver Two'), findsOneWidget);
    });

    testWidgets('tapping inactive diver in switcher triggers switch', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      final d1 = makeDiver(id: 'd1', name: 'Diver One');
      final d2 = makeDiver(id: 'd2', name: 'Diver Two');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            currentDiverProvider.overrideWith((_) async => d1),
            diverListNotifierProvider.overrideWith(
              (_) => _MockDiverListNotifier([d1, d2]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverProfileHubPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(Icons.swap_horiz),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diver Two'));
      await tester.pumpAndSettle();
      // Sheet closed.
      expect(find.text('Diver Two'), findsNothing);
    });
  });
}
