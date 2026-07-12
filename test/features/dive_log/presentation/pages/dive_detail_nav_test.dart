import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';

// Covers the navigation contract the detail page relies on: DiveNavButtons in a
// router host fires the same `?selected=` swap the embedded surface uses. The
// embedded-vs-standalone branch and arrow keys are verified manually (a full
// DiveDetailPage needs a seeded DB).
void main() {
  testWidgets('onNavigate swaps the selected query param', (tester) async {
    String? lastLocation;
    final router = GoRouter(
      initialLocation: '/dives?selected=b',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) {
            lastLocation = state.uri.toString();
            return Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(orderedDiveIdsProvider);
                  return DiveNavButtons(
                    diveId: 'b',
                    onNavigate: (id) => context.go('/dives?selected=$id'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c']),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(lastLocation, '/dives?selected=c');
  });
}
