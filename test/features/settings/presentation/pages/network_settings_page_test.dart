import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_connection_tester.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/network/proxy/proxy_settings_store.dart';
import 'package:submersion/core/network/proxy/system/system_proxy_resolver.dart';
import 'package:submersion/core/network/proxy/system_proxy_result.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/network_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

class _Resolver implements SystemProxyResolver {
  _Resolver(this.answer);

  final SystemProxyResult answer;
  int calls = 0;

  @override
  Future<SystemProxyResult> resolve(Uri probe) async {
    calls++;
    return answer;
  }
}

/// A keychain that refuses every write, as a locked keychain does.
class _FailingKeychain extends InMemoryKeychain {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw Exception('keychain locked');
}

/// A store whose settings writes fail, as unwritable preferences do.
class _FailingStore extends ProxySettingsStore {
  _FailingStore(super.prefs, {super.storage});

  @override
  Future<void> save(ProxySettings settings) async =>
      throw Exception('disk full');
}

class _Tester extends ProxyConnectionTester {
  _Tester(this.outcome);

  final ProxyTestOutcome outcome;
  EffectiveProxy? ran;

  @override
  Future<ProxyTestOutcome> run(EffectiveProxy proxy) async {
    ran = proxy;
    return outcome;
  }
}

void main() {
  late ProxyController controller;
  late ProxySettingsStore store;
  late _Resolver resolver;

  Future<void> setUpController({
    SystemProxyResult system = const SystemProxyNone(),
    ProxySettings? saved,
    String? password,
    InMemoryKeychain? keychain,
  }) async {
    SharedPreferences.setMockInitialValues({});
    store = ProxySettingsStore(
      await SharedPreferences.getInstance(),
      storage: keychain ?? InMemoryKeychain(),
    );
    if (saved != null) await store.save(saved);
    if (password != null) await store.savePassword(password);
    resolver = _Resolver(system);
    controller = ProxyController(resolver: resolver);
    addTearDown(controller.dispose);
    await controller.initialize(store);
  }

  Widget app(
    Widget home, {
    _Tester? testerFake,
    GlobalKey<NavigatorState>? key,
  }) => ProviderScope(
    overrides: [
      proxyControllerProvider.overrideWithValue(controller),
      if (testerFake != null)
        proxyConnectionTesterProvider.overrideWithValue(testerFake),
    ],
    child: MaterialApp(
      navigatorKey: key,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    SystemProxyResult system = const SystemProxyNone(),
    ProxySettings? saved,
    String? password,
    _Tester? testerFake,
  }) async {
    await setUpController(system: system, saved: saved, password: password);
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(const Scaffold(body: NetworkSettingsPage()), testerFake: testerFake),
    );
    await tester.pumpAndSettle();
  }

  final manualSaved = ProxySettings.defaults.copyWith(mode: ProxyMode.manual);

  testWidgets('system mode shows the detected proxy', (tester) async {
    await pump(
      tester,
      system: const SystemProxyFixed(
        type: ProxyType.http,
        host: 'corp',
        port: 8080,
        viaPac: true,
      ),
    );
    expect(find.text('System proxy'), findsOneWidget);
    expect(
      find.text('Using corp:8080 (from automatic configuration)'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('proxy-host')), findsNothing);
  });

  testWidgets('opening the page in system mode detects again', (tester) async {
    await pump(tester);
    // Once in initialize, once when the page opened.
    expect(resolver.calls, 2);
  });

  testWidgets('no system proxy and unsupported PAC have their own lines', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No proxy configured on this device'), findsOneWidget);
    await pump(
      tester,
      system: const SystemProxyUnavailable(
        SystemProxyUnavailableReason.pacUnsupported,
      ),
    );
    expect(find.textContaining('Choose Manual'), findsOneWidget);
  });

  testWidgets('choosing No proxy saves at once', (tester) async {
    await pump(tester);
    await tester.tap(find.text('No proxy'));
    await tester.pumpAndSettle();
    expect(store.load().mode, ProxyMode.none);
    expect(controller.current.isDirect, isTrue);
  });

  testWidgets('a failed mode change says so', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store = _FailingStore(
      await SharedPreferences.getInstance(),
      storage: InMemoryKeychain(),
    );
    controller = ProxyController(resolver: _Resolver(const SystemProxyNone()));
    addTearDown(controller.dispose);
    await controller.initialize(store);
    await tester.pumpWidget(app(const Scaffold(body: NetworkSettingsPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No proxy'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save the proxy settings."), findsOneWidget);
    expect(controller.state.settings.mode, ProxyMode.system);
  });

  testWidgets('manual fields validate and save', (tester) async {
    await pump(tester, saved: manualSaved);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the proxy host'), findsOneWidget);
    expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('proxy-host')),
      'proxy.corp',
    );
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '3128');
    await tester.enterText(find.byKey(const ValueKey('proxy-username')), 'ann');
    await tester.enterText(find.byKey(const ValueKey('proxy-password')), 'a;b');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text("The password can't contain a semicolon"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('proxy-password')), 'pw');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.load().host, 'proxy.corp');
    expect(store.load().port, 3128);
    expect(await store.loadPassword(), 'pw');
    expect(controller.current.endpoint, 'proxy.corp:3128');
    expect(controller.current.password, 'pw');
    expect(find.text('Proxy settings saved'), findsOneWidget);
  });

  testWidgets('a pasted URL in Host is reduced to the host, filling the '
      'port', (tester) async {
    await pump(tester, saved: manualSaved);
    await tester.enterText(
      find.byKey(const ValueKey('proxy-host')),
      'http://proxy.corp:3128/',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.load().host, 'proxy.corp');
    expect(store.load().port, 3128);
    expect(controller.current.endpoint, 'proxy.corp:3128');
  });

  testWidgets('a host with spaces is refused', (tester) async {
    await pump(tester, saved: manualSaved);
    await tester.enterText(
      find.byKey(const ValueKey('proxy-host')),
      'proxy corp',
    );
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '1');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the proxy host'), findsOneWidget);
    expect(store.load().host, '');
  });

  testWidgets('a host with a list separator is refused', (tester) async {
    await pump(tester, saved: manualSaved);
    await tester.enterText(
      find.byKey(const ValueKey('proxy-host')),
      'proxy;corp',
    );
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '1');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the proxy host'), findsOneWidget);
    expect(store.load().host, '');
  });

  testWidgets('the password can be revealed and SOCKS5 changes the port '
      'hint', (tester) async {
    await pump(tester, saved: manualSaved);
    TextField field(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key)));
    expect(field('proxy-password').obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field('proxy-password').obscureText, isFalse);
    expect(field('proxy-port').decoration!.hintText, '8080');
    await tester.tap(find.text('SOCKS5'));
    await tester.pump();
    expect(field('proxy-port').decoration!.hintText, '1080');
  });

  testWidgets('an over-long SOCKS5 username is flagged on the username', (
    tester,
  ) async {
    await pump(tester, saved: manualSaved.copyWith(type: ProxyType.socks5));
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 's');
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '1080');
    await tester.enterText(
      find.byKey(const ValueKey('proxy-username')),
      'u' * 256,
    );
    await tester.enterText(find.byKey(const ValueKey('proxy-password')), 'p');
    await tester.tap(find.text('Save'));
    await tester.pump();
    final username = tester.widget<TextField>(
      find.byKey(const ValueKey('proxy-username')),
    );
    expect(username.decoration!.errorText, 'Must be 255 bytes or fewer');
  });

  testWidgets('an over-long SOCKS5 password is flagged on the password, '
      'counted in bytes', (tester) async {
    await pump(tester, saved: manualSaved.copyWith(type: ProxyType.socks5));
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 's');
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '1080');
    // 200 bytes is fine; 100 three-byte characters are 300 bytes.
    await tester.enterText(
      find.byKey(const ValueKey('proxy-username')),
      'u' * 200,
    );
    await tester.enterText(
      find.byKey(const ValueKey('proxy-password')),
      '\u5bc6' * 100,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    TextField field(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key)));
    expect(field('proxy-username').decoration!.errorText, isNull);
    expect(
      field('proxy-password').decoration!.errorText,
      'Must be 255 bytes or fewer',
    );
  });

  testWidgets('the form starts from the saved proxy and password', (
    tester,
  ) async {
    await pump(
      tester,
      saved: manualSaved.copyWith(
        type: ProxyType.socks5,
        host: 's.example',
        port: 1080,
        username: 'ann',
      ),
      password: 'pw',
    );
    TextField field(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key)));
    expect(field('proxy-host').controller!.text, 's.example');
    expect(field('proxy-port').controller!.text, '1080');
    expect(field('proxy-username').controller!.text, 'ann');
    final password = field('proxy-password');
    expect(password.controller!.text, 'pw');
    expect(password.obscureText, isTrue);
  });

  testWidgets('Test uses unsaved manual values and reports success', (
    tester,
  ) async {
    final fake = _Tester(
      const ProxyTestSuccess(
        Duration(milliseconds: 240),
        EffectiveProxy(
          kind: ProxyKind.http,
          host: 'draft.host',
          port: 9,
          source: ProxySource.manual,
        ),
      ),
    );
    await pump(tester, saved: manualSaved, testerFake: fake);
    await tester.enterText(
      find.byKey(const ValueKey('proxy-host')),
      'draft.host',
    );
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '9');
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(fake.ran!.host, 'draft.host');
    expect(
      find.text('Connected through draft.host:9 (HTTP) in 240 ms'),
      findsOneWidget,
    );
    expect(store.load().host, '');
  });

  testWidgets('Test reads a pasted URL the way Save does', (tester) async {
    final fake = _Tester(const ProxyTestTimeout());
    await pump(tester, saved: manualSaved, testerFake: fake);
    await tester.enterText(
      find.byKey(const ValueKey('proxy-host')),
      'http://proxy.corp:3128/',
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(fake.ran!.host, 'proxy.corp');
    expect(fake.ran!.port, 3128);
  });

  testWidgets('a failed save says so and can be retried', (tester) async {
    await setUpController(saved: manualSaved, keychain: _FailingKeychain());
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const Scaffold(body: NetworkSettingsPage())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'p');
    await tester.enterText(find.byKey(const ValueKey('proxy-port')), '3128');
    await tester.enterText(find.byKey(const ValueKey('proxy-username')), 'a');
    await tester.enterText(find.byKey(const ValueKey('proxy-password')), 'b');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save the proxy settings."), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNotNull);
    expect(find.text('p'), findsOneWidget);
  });

  testWidgets('Test refuses an incomplete manual proxy instead of going '
      'direct', (tester) async {
    final fake = _Tester(
      const ProxyTestSuccess(Duration.zero, EffectiveProxy.direct()),
    );
    await pump(tester, saved: manualSaved, testerFake: fake);
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(fake.ran, isNull);
    expect(find.text('Enter the proxy host'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'p');
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(fake.ran, isNull);
    expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);
  });

  testWidgets('a direct success says so', (tester) async {
    await pump(
      tester,
      testerFake: _Tester(
        const ProxyTestSuccess(
          Duration(milliseconds: 90),
          EffectiveProxy.direct(),
        ),
      ),
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connected directly in 90 ms'), findsOneWidget);
  });

  testWidgets('auth failure in system mode suggests Manual', (tester) async {
    await pump(
      tester,
      system: const SystemProxyFixed(
        type: ProxyType.http,
        host: 'corp',
        port: 8080,
      ),
      testerFake: _Tester(const ProxyTestAuthRejected()),
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This proxy requires a username and password. Choose Manual and '
        'enter them.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('each failure outcome has its message', (tester) async {
    final cases = <ProxyTestOutcome, String>{
      const ProxyTestAuthRejected():
          'The proxy rejected the username or password.',
      const ProxyTestUnreachable('p:1'):
          "Couldn't reach p:1. Check the host and port.",
      const ProxyTestTlsFailure():
          'Secure connection failed. Your network may inspect HTTPS traffic; '
          'its certificate must be trusted by this device.',
      const ProxyTestTimeout(): 'The connection timed out.',
      const ProxyTestFailed('boom'):
          'The connection failed: boom. The debug log has the full error.',
    };
    for (final entry in cases.entries) {
      await pump(
        tester,
        saved: manualSaved.copyWith(host: 'p', port: 1),
        testerFake: _Tester(entry.key),
      );
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
    }
  });

  testWidgets('back with unsaved edits asks before discarding', (tester) async {
    await setUpController(saved: manualSaved);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      app(const Scaffold(body: Text('root')), key: navKey),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: NetworkSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'unsaved');
    await tester.pump();
    await navKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('the app bar back arrow asks before discarding edits', (
    tester,
  ) async {
    await setUpController(saved: manualSaved);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('root')),
          routes: [
            GoRoute(
              path: 'network',
              builder: (_, _) =>
                  const SettingsSectionDetailPage(sectionId: 'network'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [proxyControllerProvider.overrideWithValue(controller)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push('/network'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'unsaved');
    await tester.pump();
    await tester.tap(find.byTooltip('Back to settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsNothing);
  });

  testWidgets('leaving Manual makes an unsaved draft no reason to stop '
      'back', (tester) async {
    await setUpController(saved: manualSaved);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      app(const Scaffold(body: Text('root')), key: navKey),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: NetworkSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('proxy-host')), 'unsaved');
    await tester.tap(find.text('No proxy'));
    await tester.pumpAndSettle();
    await navKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });
}
