import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/features/settings/presentation/widgets/lightroom_connect_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  AdobeImsAuthManager manager(MockClient mock) => AdobeImsAuthManager(
    store: LightroomAuthStore(storage: InMemoryKeychain()),
    httpClient: mock,
    verifierGenerator: () => 'a' * 43,
  );

  MockClient happyMock() => MockClient(
    (request) async => http.Response(
      '{"access_token":"at","refresh_token":"rt","expires_in":3600}',
      200,
      headers: {'content-type': 'application/json'},
    ),
  );

  Future<void> pumpDialog(
    WidgetTester tester,
    AdobeImsAuthManager auth, {
    List<Uri>? opened,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
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
                builder: (_) => LightroomConnectDialog(
                  authManager: auth,
                  clientId: 'cid',
                  clientSecret: 'sec',
                  openUri: (uri) async {
                    opened?.add(uri);
                    return true;
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

  testWidgets('opens the IMS authorize URL on launch', (tester) async {
    final opened = <Uri>[];
    await pumpDialog(tester, manager(happyMock()), opened: opened);
    expect(opened, hasLength(1));
    expect(opened.single.host, 'ims-na1.adobelogin.com');
    expect(opened.single.queryParameters['client_id'], 'cid');
  });

  testWidgets('empty submit shows the empty-code error', (tester) async {
    await pumpDialog(tester, manager(happyMock()));
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(
      find.text('Paste the redirected URL or authorization code'),
      findsOneWidget,
    );
  });

  testWidgets('pasting a redirected URL exchanges the code and pops true', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"access_token":"at","refresh_token":"rt","expires_in":3600}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await pumpDialog(tester, manager(mock));
    await tester.enterText(
      find.byType(TextField),
      'https://submersion.app/lightroom/callback?code=xyz',
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.byType(LightroomConnectDialog), findsNothing);
    final body = Uri.splitQueryString(requests.single.body);
    expect(body['code'], 'xyz');
    expect(body['code_verifier'], 'a' * 43);
  });

  testWidgets('a rejected exchange surfaces the error in the field', (
    tester,
  ) async {
    final mock = MockClient((_) async => http.Response('denied', 400));
    await pumpDialog(tester, manager(mock));
    await tester.enterText(find.byType(TextField), 'badcode');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.byType(LightroomConnectDialog), findsOneWidget);
    expect(
      find.textContaining('Could not connect to Lightroom'),
      findsOneWidget,
    );
  });
}
