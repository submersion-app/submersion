import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('zero divers redirects initial route to the setup wizard', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(
      overrides: [
        ...overrides,
        hasAnyDiversProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    // OceanBackground animates forever; use fixed pumps, not pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SetupWizardPage), findsOneWidget);
    expect(find.text('Welcome to Submersion'), findsOneWidget);
  });
}
