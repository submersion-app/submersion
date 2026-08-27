import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart';

void main() {
  testWidgets('tapping the toggle flips showBuiltInSitesProvider', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BuiltInSitesToggleButton()),
        ),
      ),
    );

    expect(container.read(showBuiltInSitesProvider), isFalse);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(container.read(showBuiltInSitesProvider), isTrue);
  });
}
