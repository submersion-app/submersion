import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/data/services/lightroom_scan_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
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
  int prepareCalls = 0;
  Object? throwOnScan;

  /// What [prepareForDive] finds for the dive.
  List<PreparedMedia> found = const [];

  @override
  Future<({List<PreparedMedia> rows, LightroomScanSummary summary})>
  prepareForDive({
    required domain.ConnectedAccount account,
    required Dive dive,
    required LightroomConnectorState state,
  }) async {
    prepareCalls++;
    if (throwOnScan != null) throw throwOnScan!;
    return (
      rows: found,
      summary: LightroomScanSummary()..attached = found.length,
    );
  }

  @override
  Future<LightroomScanSummary> scanDives({
    required domain.ConnectedAccount account,
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
  final account = domain.ConnectedAccount(
    id: 'acct1',
    kind: AccountKind.adobeLightroom,
    label: 'Eric',
    accountIdentifier: 'cat1',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  Future<(_FakeScanService, WidgetTester)> pump(
    WidgetTester tester, {
    domain.ConnectedAccount? withAccount,
    EditSession<Dive>? sitting,
    List<Dive>? forDives,
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
                onPressed: () => sitting == null
                    ? runLightroomScan(context, ref, [
                        Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1, 10)),
                      ])
                    : forDives != null
                    ? runLightroomScanForDivesInSitting(
                        context,
                        ref,
                        sitting,
                        forDives,
                      )
                    : runLightroomScanInSitting(context, ref, sitting),
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

  group('in a sitting on the dive (issue #4527)', () {
    /// The open Media card's sitting, with writers that write nothing.
    EditSession<Dive> openSitting() {
      final session = EditSession<Dive>(
        Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1, 10)),
      );
      addTearDown(session.dispose);
      holdSittingMedia(
        session,
        SittingMediaWriters(
          writeRows: (_) async => const [],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (_, _, _) async {},
          drainDeletes: () async {},
          enqueueUpload: (_) {},
        ),
        cardId: DiveDetailSectionId.media.name,
      );
      return session;
    }

    final found = MediaItem(
      id: 'm1',
      diveId: 'd1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.serviceConnector,
      connectorAccountId: 'acct1',
      remoteAssetId: 'lr1',
      takenAt: DateTime.utc(2026, 7, 1, 10, 30),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

    testWidgets('what the scan finds is held until Save, not written', (
      tester,
    ) async {
      final session = openSitting();
      final (service, _) = await pump(
        tester,
        withAccount: account,
        sitting: session,
      );
      service.found = [(item: found, enrichment: null)];

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();

      expect(service.prepareCalls, 1);
      expect(service.scanCalls, 0);
      expect(sittingMedia(session).added.map((a) => a.preview.remoteAssetId), [
        'lr1',
      ]);
    });

    testWidgets("a trip's scan prepares each of its dives, holds what it "
        'finds once, and suggests nothing (issue #4527, plan 10)', (
      tester,
    ) async {
      final session = openSitting();
      final (service, _) = await pump(
        tester,
        withAccount: account,
        sitting: session,
        forDives: [
          Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1, 10)),
          Dive(id: 'd2', dateTime: DateTime.utc(2026, 7, 1, 14)),
        ],
      );
      service.found = [(item: found, enrichment: null)];

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();

      expect(service.prepareCalls, 2);
      expect(service.scanCalls, 0);
      expect(sittingMedia(session).added, hasLength(1));
    });

    testWidgets('a second scan does not hold the same photo twice', (
      tester,
    ) async {
      final session = openSitting();
      final (service, _) = await pump(
        tester,
        withAccount: account,
        sitting: session,
      );
      // Held rows are not stored yet, so the catalog finds them again.
      service.found = [(item: found, enrichment: null)];

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();
      service.found = [(item: found.copyWith(id: 'm2'), enrichment: null)];
      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();

      expect(sittingMedia(session).added, hasLength(1));
    });

    testWidgets('finding nothing says so and holds nothing', (tester) async {
      final session = openSitting();
      await pump(tester, withAccount: account, sitting: session);

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();

      expect(sittingMedia(session).added, isEmpty);
      expect(find.text('No new photos found near this dive'), findsOneWidget);
    });

    testWidgets('a sitting that ended during the scan holds nothing', (
      tester,
    ) async {
      final session = EditSession<Dive>(
        Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1, 10)),
      );
      final (service, _) = await pump(
        tester,
        withAccount: account,
        sitting: session,
      );
      service.found = [(item: found, enrichment: null)];
      session.dispose();

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();

      // The scan ran and found a photo, and holding it into the ended
      // sitting neither threw nor said anything.
      expect(service.prepareCalls, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
