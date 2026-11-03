import 'package:submersion/core/platform/web_database_status.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Which storage a browser's database landed in and how long the dives stay
/// there (issue #4121), for the Sync page's storage row and Settings >
/// Data's (issue #4187).
String describeWebStorage(AppLocalizations l10n, WebDatabaseStatus status) =>
    switch (status.storage) {
      WebDatabaseStorage.opfsShared ||
      WebDatabaseStorage.opfsLocks => l10n.web_storage_opfs,
      WebDatabaseStorage.sharedIndexedDb ||
      WebDatabaseStorage.unsafeIndexedDb ||
      WebDatabaseStorage.unknown => l10n.web_storage_indexedDb,
      WebDatabaseStorage.inMemory => l10n.web_storage_memoryWarning,
    };
