import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_download_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A failed copy is a local fault, so it must not read as a sync failure
/// (issue #4121).
void main() {
  testWidgets('a failed download says the backup failed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BackupDownloadTile(
              readImage: () async => throw StateError('out of memory'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.textContaining(en.web_downloadBackup_failed), findsOneWidget);
    expect(
      find.textContaining(en.settings_cloudSync_message_syncFailed),
      findsNothing,
    );
  });
}
