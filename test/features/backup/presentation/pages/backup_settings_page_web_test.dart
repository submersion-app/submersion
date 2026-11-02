import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/backup/presentation/pages/backup_settings_page.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_download_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';

/// A browser has no backup files, folders or schedules (issue #4121): its
/// Backups page offers one thing, a download of the database.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  testWidgets('offers the download and nothing file-bound', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
        child: const BackupSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackupDownloadTile), findsOneWidget);
    expect(find.text(en.web_downloadBackup_title), findsOneWidget);
    expect(find.text(en.settings_backups_backUpNow), findsNothing);
    expect(find.text(en.settings_backups_auto), findsNothing);
    expect(find.text(en.settings_backups_restoreFile), findsNothing);
  });
}
