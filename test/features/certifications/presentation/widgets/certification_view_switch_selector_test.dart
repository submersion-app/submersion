import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_view_switch_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _buildTestWidget({
  required String initialLocation,
  required CertificationView currentView,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/certifications',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('list'),
              ElevatedButton(
                onPressed: () => _openSheet(context, CertificationView.list),
                child: const Text('open'),
              ),
            ],
          ),
        ),
        routes: [
          GoRoute(
            path: 'wallet',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('wallet'),
                  ElevatedButton(
                    onPressed: () =>
                        _openSheet(context, CertificationView.wallet),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void _openSheet(BuildContext context, CertificationView currentView) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => CertificationViewSwitchSelector(currentView: currentView),
  );
}

void main() {
  group('CertificationViewSwitchSelector', () {
    testWidgets('selecting Certification Wallet from the list pushes the '
        'wallet route', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialLocation: '/certifications',
          currentView: CertificationView.list,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Certification Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('wallet'), findsOneWidget);
    });

    testWidgets('selecting List from the wallet (pushed from the list) pops '
        'back to it', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialLocation: '/certifications',
          currentView: CertificationView.list,
        ),
      );
      // Reach the wallet the same way the production wallet icon does: a
      // push from the list, so a pop is available afterwards.
      GoRouter.of(
        tester.element(find.text('list')),
      ).push('/certifications/wallet');
      await tester.pumpAndSettle();
      expect(find.text('wallet'), findsOneWidget);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      expect(find.text('wallet'), findsNothing);
    });

    testWidgets('selecting the view already shown just closes the sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(
          initialLocation: '/certifications',
          currentView: CertificationView.list,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      expect(find.byType(CertificationViewSwitchSelector), findsNothing);
    });
  });
}
