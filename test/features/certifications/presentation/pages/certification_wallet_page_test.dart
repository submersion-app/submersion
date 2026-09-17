import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_wallet_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_grid.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_share_sheet.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifier
// ---------------------------------------------------------------------------

class _MockCertificationListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _MockCertificationListNotifier(List<Certification> certifications)
    : super(AsyncValue.data(certifications));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _now = DateTime(2026, 8, 9);

Certification _makeCert({
  String id = 'cert-1',
  String name = 'Open Water Diver',
  CertificationAgency agency = CertificationAgency.padi,
}) {
  return Certification(
    id: id,
    name: name,
    agency: agency,
    createdAt: _now,
    updatedAt: _now,
  );
}

final _diver = Diver(
  id: 'diver-1',
  name: 'Eric Griffin',
  createdAt: _now,
  updatedAt: _now,
);

// ---------------------------------------------------------------------------
// Test widget harness
// ---------------------------------------------------------------------------

Widget _buildTestWidget({required List<Override> overrides}) {
  final router = GoRouter(
    initialLocation: '/certifications/wallet',
    routes: [
      GoRoute(
        path: '/certifications/wallet',
        builder: (context, state) => const CertificationWalletPage(),
      ),
      GoRoute(
        path: '/certifications/new',
        builder: (context, state) => const Scaffold(body: Text('new')),
      ),
      GoRoute(
        path: '/certifications/:id',
        builder: (context, state) =>
            Scaffold(body: Text('detail-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/certifications/:id/edit',
        builder: (context, state) =>
            Scaffold(body: Text('edit-${state.pathParameters['id']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('CertificationWalletPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> baseOverrides({List<Certification>? certifications}) {
      return [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        currentDiverProvider.overrideWith((ref) async => _diver),
        certificationListNotifierProvider.overrideWith(
          (ref) =>
              _MockCertificationListNotifier(certifications ?? [_makeCert()]),
        ),
      ];
    }

    testWidgets('renders the certification cards in a grid', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(
            certifications: [
              _makeCert(id: 'cert-1'),
              _makeCert(id: 'cert-2', agency: CertificationAgency.ssi),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CertificationEcardGrid), findsOneWidget);
      expect(find.byType(CertificationEcard), findsNWidgets(2));
    });

    testWidgets('shows the empty state when there are no certifications', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(overrides: baseOverrides(certifications: const [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No certifications yet'), findsOneWidget);
    });

    testWidgets('tapping the share icon on a card opens the share sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Share certification'));
      await tester.pumpAndSettle();

      expect(find.byType(CertificationShareSheet), findsOneWidget);
    });

    testWidgets('tapping the more-options icon opens the options sheet with '
        'share, view details and edit', (tester) async {
      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('the options sheet\'s "View Details" navigates to the '
        'certification detail route', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(certifications: [_makeCert(id: 'cert-1')]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      expect(find.text('detail-cert-1'), findsOneWidget);
    });

    testWidgets('the options sheet\'s "Edit" navigates to the certification '
        'edit route', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(certifications: [_makeCert(id: 'cert-1')]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('edit-cert-1'), findsOneWidget);
    });

    testWidgets('long-pressing a card opens the same options sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(CertificationEcard));
      await tester.pumpAndSettle();

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('the add button navigates to the new-certification route', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add certification'));
      await tester.pumpAndSettle();

      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('shows the error state with a retry button', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            currentDiverProvider.overrideWith((ref) async => _diver),
            certificationListNotifierProvider.overrideWith(
              (ref) => _ErroringCertificationListNotifier(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load certifications'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

class _ErroringCertificationListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _ErroringCertificationListNotifier()
    : super(const AsyncValue.error('boom', StackTrace.empty));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
