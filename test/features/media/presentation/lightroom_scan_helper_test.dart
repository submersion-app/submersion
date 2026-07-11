import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/data/services/lightroom_scan_service.dart';
import 'package:submersion/features/media/domain/entities/connector_account.dart'
    as domain;
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeScanService extends LightroomScanService {
  _FakeScanService()
    : super(
        api: LightroomApiClient(auth: AdobeImsAuthManager()),
        mediaRepository: MediaRepository(),
        diveRepository: DiveRepository(),
        enqueueUpload: (_) {},
      );

  int scanCalls = 0;
  Object? throwOnScan;

  @override
  Future<LightroomScanSummary> scanDives({
    required domain.ConnectorAccount account,
    required List<Dive> dives,
    required LightroomConnectorState state,
  }) async {
    scanCalls++;
    if (throwOnScan != null) throw throwOnScan!;
    return LightroomScanSummary()
      ..attached = 3
      ..suggested = 1
      ..skippedExisting = 2;
  }
}

void main() {
  final account = domain.ConnectorAccount(
    id: 'acct1',
    connectorType: 'lightroom',
    displayName: 'Eric',
    credentialsRef: 'lightroom_auth',
    accountIdentifier: 'cat1',
    addedAt: DateTime.utc(2026, 7, 1),
  );

  Future<(_FakeScanService, WidgetTester)> pump(
    WidgetTester tester, {
    domain.ConnectorAccount? withAccount,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _FakeScanService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          lightroomAccountProvider.overrideWith((ref) async => withAccount),
          lightroomScanServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => runLightroomScan(context, ref, [
                  Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1, 10)),
                ]),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
      ),
    );
    return (service, tester);
  }

  testWidgets('shows the summary snackbar after a scan', (tester) async {
    final (service, _) = await pump(tester, withAccount: account);
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    expect(service.scanCalls, 1);
    expect(
      find.text('3 linked, 1 suggested, 2 already linked'),
      findsOneWidget,
    );
  });

  testWidgets('does nothing without an account', (tester) async {
    final (service, _) = await pump(tester);
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    expect(service.scanCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed scan shows the error and records it as the '
      'connector last-error', (tester) async {
    final (service, _) = await pump(tester, withAccount: account);
    service.throwOnScan = const CloudStorageException('Adobe said no');

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    expect(find.text('Adobe said no'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final lastError = await LightroomConnectorState(
      prefs: prefs,
      accountId: account.id,
    ).lastError();
    expect(lastError, 'Adobe said no');
  });
}
