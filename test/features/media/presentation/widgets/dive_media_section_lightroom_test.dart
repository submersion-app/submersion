import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/domain/entities/connector_account.dart'
    as domain;
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final account = domain.ConnectorAccount(
    id: 'acct1',
    connectorType: 'lightroom',
    displayName: 'Eric',
    credentialsRef: 'lightroom_auth',
    accountIdentifier: 'cat1',
    addedAt: DateTime.utc(2026, 7, 1),
  );

  Future<void> pump(
    WidgetTester tester, {
    domain.ConnectorAccount? withAccount,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            lightroomAccountProvider.overrideWith((ref) async => withAccount),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveMediaSection(diveId: 'd-none'),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  testWidgets('shows the Lightroom scan action when connected and taps it '
      'safely for a missing dive', (tester) async {
    await pump(tester, withAccount: account);

    final button = find.byTooltip('Scan Lightroom');
    expect(button, findsOneWidget);

    // The dive id does not exist: _scanLightroom loads null and returns
    // without scanning or crashing.
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the Lightroom scan action when not connected', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byTooltip('Scan Lightroom'), findsNothing);
  });
}
