import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/google_web_client_id_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';
import 'package:submersion/features/settings/presentation/widgets/google_web_client_id_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

class _FullStore extends GoogleWebClientIdStore {
  _FullStore() : super(storage: InMemoryKeychain());

  @override
  Future<void> write(String clientId) async =>
      throw StateError('storage is full');
}

/// Browser storage can refuse a write: the dialog says so and stays usable
/// (issue #4121).
void main() {
  testWidgets('a failed write shows the error and frees the buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleWebClientIdStoreProvider.overrideWithValue(_FullStore()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GoogleWebClientIdDialog()),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      '433819313354-abc123def.apps.googleusercontent.com',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('storage is full'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
