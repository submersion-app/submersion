import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/data/services/lightroom_scan_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _CountingScanService extends LightroomScanService {
  _CountingScanService()
    : super(
        api: LightroomApiClient(auth: AdobeImsAuthManager()),
        mediaRepository: MediaRepository(),
        diveRepository: DiveRepository(),
        enqueueUpload: (_) {},
      );

  int pollCalls = 0;
  Object? throwOnPoll;

  @override
  Future<LightroomScanSummary> poll({
    required domain.ConnectedAccount account,
    required LightroomConnectorState state,
  }) async {
    pollCalls++;
    if (throwOnPoll != null) throw throwOnPoll!;
    await state.setLastPollAt(DateTime.now());
    return LightroomScanSummary();
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

  late SharedPreferences prefs;
  late _CountingScanService service;

  ProviderContainer container({domain.ConnectedAccount? withAccount}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        lightroomAccountProvider.overrideWith((ref) async => withAccount),
        lightroomScanServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _CountingScanService();
  });

  test('polls when enabled and never polled before', () async {
    final c = container(withAccount: account);
    await c.read(lightroomAutoPollProvider.future);
    expect(service.pollCalls, 1);
  });

  test('skips when auto-poll is disabled', () async {
    await LightroomConnectorState(
      prefs: prefs,
      accountId: account.id,
    ).setAutoPollEnabled(false);
    final c = container(withAccount: account);
    await c.read(lightroomAutoPollProvider.future);
    expect(service.pollCalls, 0);
  });

  test('skips when the last poll is recent', () async {
    await LightroomConnectorState(
      prefs: prefs,
      accountId: account.id,
    ).setLastPollAt(DateTime.now().subtract(const Duration(hours: 1)));
    final c = container(withAccount: account);
    await c.read(lightroomAutoPollProvider.future);
    expect(service.pollCalls, 0);
  });

  test('polls again when the last poll is stale', () async {
    await LightroomConnectorState(
      prefs: prefs,
      accountId: account.id,
    ).setLastPollAt(DateTime.now().subtract(const Duration(hours: 7)));
    final c = container(withAccount: account);
    await c.read(lightroomAutoPollProvider.future);
    expect(service.pollCalls, 1);
  });

  test('no-op without an account', () async {
    final c = container();
    await c.read(lightroomAutoPollProvider.future);
    expect(service.pollCalls, 0);
  });

  test('a failed poll is swallowed and recorded as the last error', () async {
    service.throwOnPoll = Exception('network down');
    final c = container(withAccount: account);
    await c.read(lightroomAutoPollProvider.future);

    expect(service.pollCalls, 1);
    final lastError = await LightroomConnectorState(
      prefs: prefs,
      accountId: account.id,
    ).lastError();
    expect(lastError, contains('network down'));
  });
}
