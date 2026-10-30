import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
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

    // RadioGroup (non-toggleable) never calls onChanged for a tap on the
    // value already selected, so nothing happens -- not even closing the
    // sheet -- the same as tapping the active option on any other radio
    // list in the app.
    testWidgets('tapping the view already shown does nothing', (tester) async {
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

      expect(find.byType(CertificationViewSwitchSelector), findsOneWidget);
    });
  });
}
