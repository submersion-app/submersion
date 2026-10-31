import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/clipboard_recorder.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  // The dialog's own copy, not a platform message: url_launcher fails in
  // ways that mean nothing to a diver (a PlatformException from GIO on
  // Linux, a bare false everywhere else), so both shapes route here.
  const browserError =
      'Could not open your browser. Use Copy link and paste the address '
      'into your browser.';

  DropboxStorageProvider provider(MockClient mock) {
    final auth = DropboxAuthManager(
      appKey: 'k',
      store: DropboxAuthStore(storage: InMemoryKeychain()),
      httpClient: mock,
      verifierGenerator: () => 'a' * 43,
    );
    return DropboxStorageProvider(
      authManager: auth,
      apiClient: DropboxApiClient(
        getAccessToken: auth.getAccessToken,
        onAccessTokenRejected: auth.invalidateAccessToken,
        httpClient: mock,
      ),
    );
  }

  MockClient happyMock() => MockClient((request) async {
    if (request.url.path == '/oauth2/token') {
      return http.Response(
        '{"access_token":"at","refresh_token":"rt","expires_in":14400}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      '{"email":"d@example.com","name":{"display_name":"Diver"}}',
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  Future<void> pumpDialog(
    WidgetTester tester,
    DropboxStorageProvider p, {
    List<Uri>? opened,
    bool openResult = true,
    List<bool>? openResultQueue,
    Object? openThrows,
    String? expectedAccount,
    ValueChanged<String>? onDifferentAccount,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // flutter_test forwards the HOST locale list, so an unpinned
        // MaterialApp renders these dialogs translated on a non-English dev
        // machine and every English expectation below misses.
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => DropboxConnectDialog(
                  provider: p,
                  expectedAccount: expectedAccount,
                  onDifferentAccount: onDifferentAccount,
                  openUri: (uri) async {
                    opened?.add(uri);
                    if (openThrows != null) throw openThrows;
                    if (openResultQueue != null && openResultQueue.isNotEmpty) {
                      return openResultQueue.removeAt(0);
                    }
                    return openResult;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('another account closes the dialog without a connect error', (
    tester,
  ) async {
    final other = <String>[];
    await pumpDialog(
      tester,
      provider(happyMock()),
      expectedAccount: 'someone@example.com',
      onDifferentAccount: other.add,
    );

    await tester.enterText(find.byType(TextField), 'the-code');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(other, ['d@example.com']);
    expect(find.text('Connect Dropbox'), findsNothing);
  });

  testWidgets('opens the authorize URL on launch and again via Reopen '
      'browser', (tester) async {
    final opened = <Uri>[];
    await pumpDialog(tester, provider(happyMock()), opened: opened);
    expect(opened, hasLength(1));
    expect(opened.single.host, 'www.dropbox.com');

    await tester.tap(find.text('Reopen browser'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(2));
    // Same PKCE verifier both times: identical URL.
    expect(opened[1], opened[0]);
  });

  testWidgets('a false return from openUri surfaces the browser error '
      'inline', (tester) async {
    // launchUrl reports "no browser opened" by returning false, not by
    // throwing; the dialog must not stay silent about it.
    await pumpDialog(tester, provider(happyMock()), openResult: false);
    expect(find.text(browserError), findsOneWidget);
    expect(find.text('Connect Dropbox'), findsOneWidget);
  });

  testWidgets('a thrown launch failure points at Copy link rather than '
      'dumping the raw platform exception', (tester) async {
    // url_launcher_linux reports "no https scheme handler registered" by
    // throwing a PlatformException. A raw toString() in the error slot told
    // the user nothing they could act on.
    await pumpDialog(
      tester,
      provider(happyMock()),
      openThrows: PlatformException(code: 'Launch Error', message: 'no app'),
    );
    expect(find.text(browserError), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
  });

  testWidgets('a successful Reopen browser clears the stale browser error', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      provider(happyMock()),
      openResultQueue: [false, true],
    );
    expect(find.text(browserError), findsOneWidget);

    await tester.tap(find.text('Reopen browser'));
    await tester.pumpAndSettle();
    expect(find.text(browserError), findsNothing);
  });

  testWidgets('Copy link puts the authorize URL on the clipboard', (
    tester,
  ) async {
    // The escape hatch that makes the dialog usable when no browser opens.
    // A Linux desktop whose GIO handler is stale reports a SUCCESSFUL
    // launch and shows nothing, so no error state can be relied on to
    // reveal this affordance -- it is always present.
    final calls = recordClipboardCalls();
    final opened = <Uri>[];
    await pumpDialog(tester, provider(happyMock()), opened: opened);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copiedText(calls), opened.single.toString());
    expect(
      find.text('Link copied. Paste it into your browser to authorize.'),
      findsOneWidget,
    );
  });

  testWidgets('Copy link copies the same URL the browser was given, so the '
      'pasted code still matches the pending PKCE verifier', (tester) async {
    final calls = recordClipboardCalls();
    final opened = <Uri>[];
    await pumpDialog(
      tester,
      provider(happyMock()),
      opened: opened,
      openResult: false,
    );
    expect(find.text(browserError), findsOneWidget);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copiedText(calls), opened.single.toString());
    // The copy confirmation replaces the failure: the user has what they
    // need, and leaving both up reads as two contradictory statuses.
    expect(find.text(browserError), findsNothing);
  });

  testWidgets('a clipboard that refuses the copy says so instead of throwing '
      'out of the button handler', (tester) async {
    // Clipboard.setData is a platform-channel call. An escaping exception
    // would leave a dead button in front of the one user who needs it most:
    // the one whose browser never opened.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpDialog(tester, provider(happyMock()));
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Could not copy the link.'), findsOneWidget);
    expect(
      find.text('Link copied. Paste it into your browser to authorize.'),
      findsNothing,
    );
    // Still usable: the code field and Connect are untouched.
    expect(find.text('Connect Dropbox'), findsOneWidget);
  });

  testWidgets('empty code shows validation error and does not close', (
    tester,
  ) async {
    await pumpDialog(tester, provider(happyMock()));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the authorization code shown in your browser'),
      findsOneWidget,
    );
    expect(find.text('Connect Dropbox'), findsOneWidget);
  });

  testWidgets('a valid code connects and pops true', (tester) async {
    final p = provider(happyMock());
    await pumpDialog(tester, p);
    await tester.enterText(find.byType(TextField), '  the-code  ');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Dropbox'), findsNothing);
    expect(await p.isAuthenticated(), isTrue);
  });

  testWidgets('a rejected code surfaces the error inline', (tester) async {
    final mock = MockClient(
      (_) async => http.Response('{"error":"invalid_grant"}', 400),
    );
    await pumpDialog(tester, provider(mock));
    await tester.enterText(find.byType(TextField), 'bad-code');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not connect to Dropbox'), findsOneWidget);
    expect(find.text('Connect Dropbox'), findsOneWidget);
  });

  testWidgets(
    'a non-storage exception (e.g. keychain PlatformException) unwedges the '
    'dialog with an inline error instead of leaving Connect disabled '
    'forever',
    (tester) async {
      // ProbeFailingKeychain's probe write throws a PlatformException whose
      // status is not errSecMissingEntitlement (-34018), so
      // FallbackSecureStorage rethrows it unchanged out of
      // DropboxAuthStore.save -- a raw PlatformException, not a
      // CloudStorageException.
      final auth = DropboxAuthManager(
        appKey: 'k',
        store: DropboxAuthStore(storage: ProbeFailingKeychain(-1)),
        httpClient: happyMock(),
        verifierGenerator: () => 'a' * 43,
      );
      final p = DropboxStorageProvider(
        authManager: auth,
        apiClient: DropboxApiClient(
          getAccessToken: auth.getAccessToken,
          onAccessTokenRejected: auth.invalidateAccessToken,
          httpClient: happyMock(),
        ),
      );
      await pumpDialog(tester, p);
      await tester.enterText(find.byType(TextField), 'the-code');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // The dialog stays open with an inline error and Connect re-enabled,
      // not permanently wedged with a stuck spinner.
      expect(find.text('Connect Dropbox'), findsOneWidget);
      expect(
        find.textContaining('Could not connect to Dropbox'),
        findsOneWidget,
      );
      final connectButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect'),
      );
      expect(connectButton.onPressed, isNotNull);
    },
  );

  testWidgets('dismissing the dialog mid-exchange does not throw when the '
      'exchange later fails', (tester) async {
    // Gate the token endpoint so the exchange is still in flight when the
    // user dismisses the dialog via the barrier.
    final gate = Completer<http.Response>();
    final mock = MockClient((_) => gate.future);
    await pumpDialog(tester, provider(mock));
    await tester.enterText(find.byType(TextField), 'the-code');
    await tester.tap(find.text('Connect'));
    await tester.pump();

    // Barrier-dismiss while completeAuthorization is pending.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Connect Dropbox'), findsNothing);

    // The exchange now fails against a disposed State: the error handler
    // must not call setState.
    gate.complete(http.Response('{"error":"invalid_grant"}', 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
