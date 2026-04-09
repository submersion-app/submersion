import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
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
}
