import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';

class _None implements SystemProxyResolver {
  @override
  Future<SystemProxyResult> resolve(Uri probe) async => const SystemProxyNone();
}

void main() {
  test(
    'state stream starts with the current state and follows changes',
    () async {
      final controller = ProxyController(resolver: _None());
      addTearDown(controller.dispose);
      final container = ProviderContainer(
        overrides: [proxyControllerProvider.overrideWithValue(controller)],
      );
      addTearDown(container.dispose);
      final seen = <ProxyMode>[];
      container.listen(proxyStateProvider, (_, next) {
        final v = next.valueOrNull;
        if (v != null) seen.add(v.settings.mode);
      }, fireImmediately: true);
      await pumpEventQueue();
      await controller.saveSettings(
        ProxySettings.defaults.copyWith(mode: ProxyMode.none),
      );
      await pumpEventQueue();
      expect(seen.first, ProxyMode.system);
      expect(seen.last, ProxyMode.none);
    },
  );

  test('the controller must be supplied by main()', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(proxyControllerProvider), throwsA(anything));
  });

  test('the draft keeps edits until cleared', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(networkProxyDraftProvider.notifier);
    expect(container.read(networkProxyDraftProvider), isNull);
    n.update(
      const NetworkProxyDraft(
        type: ProxyType.http,
        host: 'h',
        port: '1',
        username: '',
        password: '',
      ),
    );
    expect(container.read(networkProxyDraftProvider)!.host, 'h');
    n.clear();
    expect(container.read(networkProxyDraftProvider), isNull);
  });
}
