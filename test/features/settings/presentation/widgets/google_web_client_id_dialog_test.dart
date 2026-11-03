import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/google_web_client_id_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';
import 'package:submersion/features/settings/presentation/widgets/google_web_client_id_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

/// The dialog a browser shows before its first Google sign-in (issue
/// #4121): the client id of the user's own Google Cloud project, checked
/// for shape, kept with the other sign-in details.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  const valid = '433819313354-abc123def.apps.googleusercontent.com';

  Future<
    ({
      Future<bool?> Function() result,
      InMemoryKeychain keychain,
      List<Uri> opened,
    })
  >
  pumpDialog(WidgetTester tester) async {
    final keychain = InMemoryKeychain();
    final opened = <Uri>[];
    Future<bool?>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleWebClientIdStoreProvider.overrideWithValue(
            GoogleWebClientIdStore(storage: keychain),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  result = showDialog<bool>(
                    context: context,
                    builder: (_) => GoogleWebClientIdDialog(
                      openUri: (uri) async {
                        opened.add(uri);
                        return true;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (result: () => result!, keychain: keychain, opened: opened);
  }

  testWidgets('says plainly that an id of your own cannot open the library '
      'the other apps sync', (tester) async {
    await pumpDialog(tester);
    expect(find.text(en.web_googleClientId_ownProjectNote), findsOneWidget);
  });

  testWidgets('an id of the wrong shape is refused with a message', (
    tester,
  ) async {
    final dialog = await pumpDialog(tester);
    await tester.enterText(find.byType(TextField), 'not an id');
    await tester.tap(find.text(en.common_action_save));
    await tester.pumpAndSettle();
    expect(find.text(en.web_googleClientId_invalid), findsOneWidget);
    expect(find.text(en.web_googleClientId_title), findsOneWidget);
    expect(dialog.keychain.values, isEmpty);
  });

  testWidgets('a valid id is stored, trimmed, and the dialog closes', (
    tester,
  ) async {
    final dialog = await pumpDialog(tester);
    await tester.enterText(find.byType(TextField), '  $valid ');
    await tester.tap(find.text(en.common_action_save));
    await tester.pumpAndSettle();
    expect(await dialog.result(), isTrue);
    expect(dialog.keychain.values[GoogleWebClientIdStore.key], valid);
    expect(find.text(en.web_googleClientId_title), findsNothing);
  });

  testWidgets('cancel stores nothing', (tester) async {
    final dialog = await pumpDialog(tester);
    await tester.enterText(find.byType(TextField), valid);
    await tester.tap(find.text(en.common_action_cancel));
    await tester.pumpAndSettle();
    expect(await dialog.result(), isNot(isTrue));
    expect(dialog.keychain.values, isEmpty);
  });

  testWidgets('the help link opens the web guide\'s Google Drive section', (
    tester,
  ) async {
    final dialog = await pumpDialog(tester);
    await tester.tap(find.text(en.web_googleClientId_help));
    await tester.pumpAndSettle();
    expect(dialog.opened.single.toString(), contains('web-app'));
    expect(dialog.opened.single.fragment, 'google-drive');
  });
}
