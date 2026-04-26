import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _wrap() => const ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaSourcesPage(),
  ),
);

void main() {
  testWidgets('renders Photo library entry and Show hidden picker tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Media Sources'), findsOneWidget);
    expect(find.text('Photo library'), findsOneWidget);
    expect(find.text('Show hidden picker tabs'), findsOneWidget);
    expect(find.text('Hidden by default'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('toggling switch flips mediaPickerHiddenTabsProvider', (
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
          home: MediaSourcesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(mediaPickerHiddenTabsProvider), isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(mediaPickerHiddenTabsProvider), isTrue);
    expect(
      find.text('Files and URL tabs visible in picker (debug)'),
      findsOneWidget,
    );
  });
}
