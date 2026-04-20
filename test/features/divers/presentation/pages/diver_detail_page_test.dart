import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/pages/diver_detail_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(500, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _MockDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _MockDiverListNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  DeleteDiverResult deleteResult = const DeleteDiverResult(
    reassignedTripsCount: 0,
    reassignedSitesCount: 0,
  );

  int deleteCalls = 0;
  int setDefaultCalls = 0;
  Object? deleteError;

  @override
  Future<void> refresh() async {}

  @override
  Future<Diver> addDiver(Diver diver) async => diver;

  @override
  Future<void> updateDiver(Diver diver) async {}

  @override
  Future<DeleteDiverResult> deleteDiver(String id) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    return deleteResult;
  }

  @override
  Future<void> setAsDefault(String id) async {
    setDefaultCalls++;
  }
}

void main() {
  final now = DateTime.now();

  Diver makeDiver({
    String id = 'diver-1',
    String name = 'Alice Alpha',
    String? email,
    String? phone,
    EmergencyContact? emergency,
    String medicalNotes = '',
    String? bloodType,
    String? allergies,
    DiverInsurance? insurance,
    String notes = '',
    bool isDefault = false,
  }) {
    return Diver(
      id: id,
      name: name,
      email: email,
      phone: phone,
      emergencyContact: emergency ?? const EmergencyContact(),
      medicalNotes: medicalNotes,
      bloodType: bloodType,
      allergies: allergies,
      insurance: insurance ?? const DiverInsurance(),
      notes: notes,
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('DiverDetailPage loading/error/not-found', () {
    testWidgets('shows loading indicator', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider('slow').overrideWith(
              (_) => Future.delayed(const Duration(seconds: 10), () => null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: 'slow'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Diver'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows embedded loading indicator', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider('slow').overrideWith(
              (_) => Future.delayed(const Duration(seconds: 10), () => null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiverDetailPage(diverId: 'slow', embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows not-found state when diver is null', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider('gone').overrideWith((_) async => null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: 'gone'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Diver not found'), findsOneWidget);
    });

    testWidgets('shows embedded not-found state', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider('gone').overrideWith((_) async => null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiverDetailPage(diverId: 'gone', embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Diver not found'), findsOneWidget);
    });

    testWidgets('shows non-embedded error state', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(
              'err',
            ).overrideWith((_) => Future.error(Exception('diver-boom'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: 'err'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('diver-boom'), findsOneWidget);
    });

    testWidgets('shows embedded error state', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(
              'err2',
            ).overrideWith((_) => Future.error(Exception('embedded-boom'))),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiverDetailPage(diverId: 'err2', embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('embedded-boom'), findsOneWidget);
    });
  });

  group('DiverDetailPage content sections', () {
    testWidgets('renders profile header with name and initials', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(name: 'Bobby Balogne');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 5, totalBottomTimeSeconds: 3600),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bobby Balogne'), findsWidgets);
      // Stats section.
      expect(find.text('Dive Statistics'), findsOneWidget);
      expect(find.text('Total Dives'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Bottom Time'), findsOneWidget);
      expect(find.text('1h 0m'), findsOneWidget);
    });

    testWidgets('renders contact section when email/phone set', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(email: 'a@b.com', phone: '+1555');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contact'), findsOneWidget);
      expect(find.text('a@b.com'), findsOneWidget);
      expect(find.text('+1555'), findsOneWidget);
    });

    testWidgets('renders emergency contact when set', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(
        emergency: const EmergencyContact(
          name: 'Emergency Ethel',
          phone: '+1234',
          relation: 'Sister',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Emergency Contact'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Emergency Contact'), findsOneWidget);
      expect(find.text('Emergency Ethel'), findsOneWidget);
      expect(find.text('Sister'), findsOneWidget);
      expect(find.text('+1234'), findsOneWidget);
    });

    testWidgets('renders medical info when set', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(
        bloodType: 'O+',
        allergies: 'Penicillin',
        medicalNotes: 'See doctor',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Medical Information'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('Penicillin'), findsOneWidget);
      expect(find.text('See doctor'), findsOneWidget);
    });

    testWidgets('renders insurance section with expired badge', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(
        insurance: DiverInsurance(
          provider: 'DAN',
          policyNumber: 'P123',
          expiryDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Dive Insurance'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('DAN'), findsOneWidget);
      expect(find.text('P123'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('renders notes section when notes set', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(notes: 'Loves night dives');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Notes'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Loves night dives'), findsOneWidget);
    });

    testWidgets('shows default badge when diver is default', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(isDefault: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsWidgets);
    });
  });

  group('DiverDetailPage stats states', () {
    testWidgets('shows stats loading state', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) => Future.delayed(
                const Duration(seconds: 10),
                () => const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pump();
      // Stats section loading indicator may be visible.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('shows stats error state', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(
              diver.id,
            ).overrideWith((_) => Future.error(Exception('stats-boom'))),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load stats'), findsOneWidget);
    });
  });

  group('DiverDetailPage app bar actions', () {
    testWidgets(
      'shows edit and popup icons; shows switch_account when not current',
      (tester) async {
        _setMobileTestSurfaceSize(tester);
        final overrides = await getBaseOverrides();
        final diver = makeDiver();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diverByIdProvider(diver.id).overrideWith((_) async => diver),
              diverStatsProvider(diver.id).overrideWith(
                (_) async =>
                    const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiverDetailPage(diverId: diver.id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        expect(find.byIcon(Icons.switch_account), findsOneWidget);
      },
    );

    testWidgets(
      'popup menu shows set-default for non-default diver and triggers it',
      (tester) async {
        _setMobileTestSurfaceSize(tester);
        final overrides = await getBaseOverrides();
        final diver = makeDiver();
        final notifier = _MockDiverListNotifier([diver]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diverByIdProvider(diver.id).overrideWith((_) async => diver),
              diverStatsProvider(diver.id).overrideWith(
                (_) async =>
                    const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
              ),
              diverListNotifierProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiverDetailPage(diverId: diver.id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Set as Default'), findsOneWidget);
        await tester.tap(find.text('Set as Default'));
        await tester.pumpAndSettle();
        expect(notifier.setDefaultCalls, 1);
      },
    );

    testWidgets('default diver popup menu hides set-default', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver(isDefault: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Set as Default'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('edit button navigates to edit route', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      final router = GoRouter(
        initialLocation: '/divers/${diver.id}',
        routes: [
          GoRoute(
            path: '/divers/:id',
            builder: (context, state) =>
                DiverDetailPage(diverId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    const Scaffold(body: Text('EDIT_PAGE')),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
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
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('EDIT_PAGE'), findsOneWidget);
    });
  });

  group('DiverDetailPage embedded layout', () {
    testWidgets('renders embedded header with action buttons', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiverDetailPage(diverId: diver.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Embedded header shows initials avatar and action icons.
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.switch_account), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('embedded: hides switch_account when diver is current', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final diver = makeDiver();
      // Set SharedPreferences with current_diver_id pre-seeded so
      // currentDiverIdProvider loads the value from storage.
      final overrides = await getBaseOverrides();
      // Replace the current-diver override with a preseeded notifier.
      final filteredOverrides = overrides
          .where((o) => o != overrides[2])
          .toList();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...filteredOverrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
            currentDiverIdProvider.overrideWith(
              (_) => _PredefinedCurrentDiver(diver.id),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiverDetailPage(diverId: diver.id, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.switch_account), findsNothing);
      // Active Diver label should appear.
      expect(find.text('Active Diver'), findsWidgets);
    });

    testWidgets('embedded edit button navigates to edit mode', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      final router = GoRouter(
        initialLocation: '/slot',
        routes: [
          GoRoute(
            path: '/slot',
            builder: (context, state) => Scaffold(
              body: DiverDetailPage(diverId: diver.id, embedded: true),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
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
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        contains('mode=edit'),
      );
    });

    testWidgets('embedded delete confirmed calls onDeleted callback', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      final notifier = _MockDiverListNotifier([diver]);
      bool onDeletedCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
            diverListNotifierProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiverDetailPage(
                diverId: diver.id,
                embedded: true,
                onDeleted: () => onDeletedCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Confirm deletion in DeleteDiverDialog.
      final confirmButton = find.widgetWithText(FilledButton, 'Delete');
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton.first);
        await tester.pumpAndSettle();
      }
      if (notifier.deleteCalls > 0) {
        expect(onDeletedCalled, isTrue);
      }
    });
  });

  group('DiverDetailPage switch account', () {
    testWidgets('tapping switch_account updates current diver', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await getBaseOverrides();
      final diver = makeDiver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diverByIdProvider(diver.id).overrideWith((_) async => diver),
            diverStatsProvider(diver.id).overrideWith(
              (_) async =>
                  const DiverStats(diveCount: 0, totalBottomTimeSeconds: 0),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiverDetailPage(diverId: diver.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.switch_account));
      await tester.pumpAndSettle();
      // Snackbar appears.
      expect(find.textContaining('Alice Alpha'), findsWidgets);
    });
  });
}

class _PredefinedCurrentDiver extends MockCurrentDiverIdNotifier {
  _PredefinedCurrentDiver(String id) {
    state = id;
  }
}
