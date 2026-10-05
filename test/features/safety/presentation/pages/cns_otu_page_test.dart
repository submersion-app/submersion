import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/presentation/pages/cns_otu_page.dart';
import 'package:submersion/features/safety/presentation/providers/cns_otu_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, List<Override> overrides) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CnsOtuPage(),
        ),
      ),
    );
  }

  testWidgets('a repository failure shows the error placeholder, never a false '
      '"all clear"', (tester) async {
    await pumpPage(tester, [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      cnsOtuSnapshotProvider.overrideWith((ref) async {
        throw StateError('simulated repository failure');
      }),
    ]);
    await tester.pump();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('No active load'), findsNothing);
  });
}
