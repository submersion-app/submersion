import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_missing_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host({required bool isEmpty, int offline = 0}) {
    return ProviderScope(
      overrides: [
        missingOfflineCountProvider.overrideWith((ref) async => offline),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaMissingBanner(isEmpty: isEmpty)),
      ),
    );
  }

  testWidgets('history stays reachable with nothing missing', (tester) async {
    await tester.pumpWidget(host(isEmpty: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('Repair...'), findsNothing);
  });

  testWidgets('missing rows get the Repair entry point', (tester) async {
    await tester.pumpWidget(host(isEmpty: false));
    await tester.pumpAndSettle();
    expect(find.text('Repair...'), findsOneWidget);
  });

  testWidgets('offline volumes are reported', (tester) async {
    await tester.pumpWidget(host(isEmpty: false, offline: 2));
    await tester.pumpAndSettle();
    expect(find.text('2 on offline volumes'), findsOneWidget);
  });
}
