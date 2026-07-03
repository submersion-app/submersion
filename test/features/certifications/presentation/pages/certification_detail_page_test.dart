import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('CertificationDetailPage desktop redirect', () {
    final certification = Certification(
      id: 'cert-1',
      name: 'Open Water Diver',
      agency: CertificationAgency.padi,
      notes: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    testWidgets(
      'redirects to master-detail on desktop when not in table mode',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        final router = GoRouter(
          initialLocation: '/certifications/cert-1',
          routes: [
            GoRoute(
              path: '/certifications',
              builder: (context, state) =>
                  const Scaffold(body: Text('CERTIFICATION_LIST_PAGE')),
            ),
            GoRoute(
              path: '/certifications/:id',
              builder: (context, state) => CertificationDetailPage(
                certificationId: state.pathParameters['id']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              certificationListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              certificationByIdProvider(
                certification.id,
              ).overrideWith((ref) async => certification),
              courseForCertificationProvider(
                certification.id,
              ).overrideWith((ref) async => null),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('CERTIFICATION_LIST_PAGE'), findsOneWidget);
      },
    );

    testWidgets('does not redirect on desktop in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/certifications/cert-1',
        routes: [
          GoRoute(
            path: '/certifications',
            builder: (context, state) =>
                const Scaffold(body: Text('CERTIFICATION_LIST_PAGE')),
          ),
          GoRoute(
            path: '/certifications/:id',
            builder: (context, state) => CertificationDetailPage(
              certificationId: state.pathParameters['id']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            certificationListViewModeProvider.overrideWith(
              (ref) => ListViewMode.table,
            ),
            certificationByIdProvider(
              certification.id,
            ).overrideWith((ref) async => certification),
            courseForCertificationProvider(
              certification.id,
            ).overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CERTIFICATION_LIST_PAGE'), findsNothing);
    });
  });

  group(
    'CertificationDetailPage instructor section with cleared snapshot text',
    () {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Alice Instructor',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final certificationWithIdOnly = Certification(
        id: 'cert-2',
        name: 'Advanced Open Water',
        agency: CertificationAgency.padi,
        notes: '',
        instructorId: buddy.id,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      Future<void> pumpDetail(
        WidgetTester tester,
        List<dynamic> overrides,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides.cast(),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CertificationDetailPage(
                certificationId: 'cert-2',
                embedded: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets(
        'shows the linked buddy name when snapshot text is null but instructorId resolves',
        (tester) async {
          final overrides = await getBaseOverrides();

          await pumpDetail(tester, [
            ...overrides,
            certificationByIdProvider(
              certificationWithIdOnly.id,
            ).overrideWith((ref) async => certificationWithIdOnly),
            courseForCertificationProvider(
              certificationWithIdOnly.id,
            ).overrideWith((ref) async => null),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
          ]);

          expect(find.text('Alice Instructor'), findsOneWidget);
        },
      );

      testWidgets(
        'hides the instructor section when instructorId does not resolve to a buddy',
        (tester) async {
          final overrides = await getBaseOverrides();

          await pumpDetail(tester, [
            ...overrides,
            certificationByIdProvider(
              certificationWithIdOnly.id,
            ).overrideWith((ref) async => certificationWithIdOnly),
            courseForCertificationProvider(
              certificationWithIdOnly.id,
            ).overrideWith((ref) async => null),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => null),
          ]);

          final context = tester.element(find.byType(CertificationDetailPage));
          expect(
            find.text(
              AppLocalizations.of(
                context,
              ).certifications_detail_sectionTitle_instructor,
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'falls back to a plain (non-tappable) row when the snapshot name is '
        'present but the linked buddy does not resolve',
        (tester) async {
          final overrides = await getBaseOverrides();
          final certWithText = certificationWithIdOnly.copyWith(
            instructorName: 'Jane Snapshot',
          );

          await pumpDetail(tester, [
            ...overrides,
            certificationByIdProvider(
              certWithText.id,
            ).overrideWith((ref) async => certWithText),
            courseForCertificationProvider(
              certWithText.id,
            ).overrideWith((ref) async => null),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => null),
          ]);

          expect(find.text('Jane Snapshot'), findsOneWidget);
          // Unresolved link renders the plain row: no chevron affordance.
          expect(find.byIcon(Icons.chevron_right), findsNothing);
        },
      );

      Future<void> pumpDetailWithRouter(
        WidgetTester tester,
        List<dynamic> overrides, {
        required bool embedded,
      }) async {
        final router = GoRouter(
          initialLocation: '/detail',
          routes: [
            GoRoute(
              path: '/detail',
              builder: (context, state) => CertificationDetailPage(
                certificationId: 'cert-2',
                embedded: embedded,
              ),
            ),
            GoRoute(
              path: '/buddies',
              builder: (context, state) => const Text('BUDDIES_LIST_MARKER'),
            ),
            GoRoute(
              path: '/buddies/:buddyId',
              builder: (context, state) => const Text('BUDDY_DETAIL_MARKER'),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides.cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final (embedded, marker) in [
        (true, 'BUDDIES_LIST_MARKER'),
        (false, 'BUDDY_DETAIL_MARKER'),
      ]) {
        testWidgets(
          'tapping the linked instructor row (embedded: $embedded) navigates '
          'to the buddy',
          (tester) async {
            final overrides = await getBaseOverrides();

            await pumpDetailWithRouter(tester, [
              ...overrides,
              certificationByIdProvider(
                certificationWithIdOnly.id,
              ).overrideWith((ref) async => certificationWithIdOnly),
              courseForCertificationProvider(
                certificationWithIdOnly.id,
              ).overrideWith((ref) async => null),
              buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            ], embedded: embedded);

            await tester.ensureVisible(find.text('Alice Instructor'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Alice Instructor'));
            await tester.pumpAndSettle();
            expect(find.text(marker), findsOneWidget);
          },
        );
      }
    },
  );
}
