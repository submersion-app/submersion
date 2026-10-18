// Issue #3482 review: navigation hints spell out "Settings > Data > ..." in
// every language, so each one must start with the words the app actually
// shows for Settings and Data, and the Chinese statuses must read as
// sentences when the time is "just now".

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale path hints start with the Settings and Data labels', () {
      final l = lookupAppLocalizations(locale);
      final trail =
          '${l.settings_appBar_title} > ${l.settings_section_data_title}';
      final hints = <String, String>{
        'connections_empty_buddies': l.connections_empty_buddies,
        'settings_cloudSync_firstSync_replaceHint':
            l.settings_cloudSync_firstSync_replaceHint,
        'settings_storage_resetDialog_body':
            l.settings_storage_resetDialog_body,
        'settings_storage_resetComplete_description':
            l.settings_storage_resetComplete_description,
        'startup_interruptedRestore_recoverNote':
            l.startup_interruptedRestore_recoverNote,
        'startup_interruptedRestore_keepNote':
            l.startup_interruptedRestore_keepNote,
        'transfer_export_aboutContent': l.transfer_export_aboutContent,
        'startup_recovery_encryptedBackup_body':
            l.startup_recovery_encryptedBackup_body,
      };
      hints.forEach((key, value) {
        expect(value, contains(trail), reason: key);
      });
    });
  }

  test('Chinese statuses read as sentences right after a backup or sync', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final now = zh.settings_data_time_justNow;
    for (final s in [
      zh.settings_data_backups_status_local(now),
      zh.settings_data_backups_status_cloud(now, 'Google Drive'),
      zh.settings_data_backups_status_cloudUnknown(now),
      zh.settings_data_backups_status_folder(now),
      zh.settings_data_backups_status_plain(now),
      zh.settings_data_sync_status_synced(now),
    ]) {
      // "于" (at) needs a point in time; "刚刚" (just now) is an adverb.
      expect(s, isNot(contains('于$now')), reason: s);
      expect(s, startsWith(now), reason: s);
    }
  });
}
