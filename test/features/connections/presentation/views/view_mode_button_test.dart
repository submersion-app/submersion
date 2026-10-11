import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/views/view_mode_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('the menu lists four views and writes the choice', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(appBar: AppBar(actions: const [ViewModeButton()])),
        ),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    expect(
      find.byIcon(ViewModeButton.iconFor(ConnectionsViewKind.graph)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('connections-view-button')));
    await tester.pumpAndSettle();
    for (final label in ['Graph', 'Pairs', 'Entities', 'Matrix']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Matrix'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsDisplayProvider).view, ConnectionsViewKind.matrix);
    expect(
      find.byIcon(ViewModeButton.iconFor(ConnectionsViewKind.matrix)),
      findsOneWidget,
    );
  });
}
