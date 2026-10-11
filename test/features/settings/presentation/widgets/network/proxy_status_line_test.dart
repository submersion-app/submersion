import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/features/settings/presentation/widgets/network/proxy_status_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  ProxyControllerState state(
    SystemProxyResult? system, {
    bool detecting = false,
  }) => ProxyControllerState(
    settings: ProxySettings.defaults,
    system: system,
    detecting: detecting,
    effective: EffectiveProxy.resolve(
      settings: ProxySettings.defaults,
      system: system,
    ),
  );

  test('each OS answer has its line', () {
    expect(
      ProxyStatusLine.statusText(l10n, state(null, detecting: true)),
      "Checking this device's proxy settings",
    );
    expect(
      ProxyStatusLine.statusText(
        l10n,
        state(const SystemProxyFixed(type: ProxyType.http, host: 'h', port: 1)),
      ),
      'Using h:1',
    );
    expect(
      ProxyStatusLine.statusText(
        l10n,
        state(
          const SystemProxyFixed(type: ProxyType.socks5, host: 's', port: 2),
        ),
      ),
      'Using s:2 (SOCKS5)',
    );
    expect(
      ProxyStatusLine.statusText(
        l10n,
        state(
          const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed),
        ),
      ),
      contains("couldn't be read. Choose Manual"),
    );
    expect(
      ProxyStatusLine.statusText(
        l10n,
        state(
          const SystemProxyUnavailable(
            SystemProxyUnavailableReason.platformError,
          ),
        ),
      ),
      "This device's proxy settings couldn't be read.",
    );
  });

  testWidgets('a problem is drawn as a warning; refresh waits for detection', (
    tester,
  ) async {
    var refreshed = 0;
    Future<void> show(ProxyControllerState s) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProxyStatusLine(state: s, onRefresh: () => refreshed++),
        ),
      ),
    );
    await show(
      state(
        const SystemProxyUnavailable(SystemProxyUnavailableReason.pacFailed),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    expect(refreshed, 1);
    await show(state(null, detecting: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    expect(refreshed, 1);
  });
}
