import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';

import '../../../../helpers/test_app.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';

  Future<List<dynamic>> makeOverrides({
    required bool encryptionEnabled,
    bool withStoredKey = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'sync_encryption_enabled': encryptionEnabled,
    });
    final prefs = await SharedPreferences.getInstance();
    final keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    if (withStoredKey) {
      await keyStore.saveKey(
        libraryKeyId: keyId,
        mlkBytes: List<int>.generate(32, (i) => i),
      );
    }
    return [
      sharedPreferencesProvider.overrideWithValue(prefs),
      encryptionKeyStoreProvider.overrideWithValue(keyStore),
    ];
  }

  Widget wrap(Widget child, List<dynamic> overrides) => testApp(
    child: SingleChildScrollView(child: child),
    overrides: overrides,
  );

  group('EncryptionSettingsSection states', () {
    testWidgets('off shows the Enable action', (tester) async {
      final overrides = await makeOverrides(encryptionEnabled: false);
      await tester.pumpWidget(
        wrap(const EncryptionSettingsSection(), overrides),
      );
      await tester.pump();
      // No provider selected -> tile present but disabled with the hint.
      expect(find.text('Enable encryption'), findsOneWidget);
      expect(find.text('Select a cloud provider first'), findsOneWidget);
    });

    testWidgets('on + stored key shows manage actions', (tester) async {
      final overrides = await makeOverrides(
        encryptionEnabled: true,
        withStoredKey: true,
      );
      await tester.pumpWidget(
        wrap(const EncryptionSettingsSection(), overrides),
      );
      // Let the initState ensureLoaded() microtask + HKDF complete.
      await tester.pumpAndSettle();
      expect(find.text('Encryption is on'), findsOneWidget);
      expect(find.text('Change passphrase'), findsOneWidget);
      expect(find.text('Turn off encryption'), findsOneWidget);
    });

    testWidgets('on + no key shows the locked state with unlock action', (
      tester,
    ) async {
      final overrides = await makeOverrides(encryptionEnabled: true);
      await tester.pumpWidget(
        wrap(const EncryptionSettingsSection(), overrides),
      );
      await tester.pumpAndSettle();
      expect(find.text('Encrypted — passphrase needed'), findsOneWidget);
      expect(find.text('Enter passphrase'), findsOneWidget);
    });
  });

  group('EnableEncryptionDialog', () {
    testWidgets('mismatched confirm shows an error and never enables', (
      tester,
    ) async {
      var enableCalls = 0;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EnableEncryptionDialog(
                  onEnable: (_) async {
                    enableCalls++;
                    return 'code';
                  },
                  onFinished: (_) async {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase'),
        'longenough1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        'different1',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Passphrases do not match'), findsOneWidget);
      expect(enableCalls, 0);
    });

    testWidgets('happy path reaches the recovery step; Done gated on the '
        'saved checkbox', (tester) async {
      final finishedWith = <bool>[];
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EnableEncryptionDialog(
                  onEnable: (_) async => 'acid-acorn-acre-act',
                  onFinished: (delete) async => finishedWith.add(delete),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase'),
        'longenough1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        'longenough1',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('acid-acorn-acre-act'), findsOneWidget);
      final doneButton = find.widgetWithText(FilledButton, 'Done');
      expect(tester.widget<FilledButton>(doneButton).onPressed, isNull);

      await tester.tap(find.text('I have saved my recovery code'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(doneButton).onPressed, isNotNull);

      await tester.tap(doneButton);
      await tester.pumpAndSettle();
      expect(finishedWith, [true], reason: 'delete-backups defaults to on');
    });

    testWidgets('too-short passphrase blocks Continue', (tester) async {
      var enableCalls = 0;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EnableEncryptionDialog(
                  onEnable: (_) async {
                    enableCalls++;
                    return 'code';
                  },
                  onFinished: (_) async {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        'short',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(enableCalls, 0);
    });

    testWidgets('onEnable failure returns to the form with an error', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EnableEncryptionDialog(
                  onEnable: (_) async => throw Exception('upload failed'),
                  onFinished: (_) async {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase'),
        'longenough1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm passphrase'),
        'longenough1',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Back on the form (Continue still present) with the error surfaced.
      expect(find.textContaining('upload failed'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('cancel closes the dialog without enabling', (tester) async {
      var enableCalls = 0;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EnableEncryptionDialog(
                  onEnable: (_) async {
                    enableCalls++;
                    return 'code';
                  },
                  onFinished: (_) async {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(EnableEncryptionDialog), findsNothing);
      expect(enableCalls, 0);
    });
  });
}
