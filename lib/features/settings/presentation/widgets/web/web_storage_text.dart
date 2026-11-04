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

/// The remember switch's subtitle (issue #4187): it says the dives stay
/// whether the switch is on or off, except in a browser that keeps nothing
/// after the tab closes, where it says that instead. Before the database is
/// open ([status] null) it reads as the lasting kinds do.
String rememberSwitchSubtitle(
  AppLocalizations l10n,
  WebDatabaseStatus? status,
) => status?.persists == false
    ? l10n.web_rememberOnThisDevice_subtitleInMemory
    : l10n.web_rememberOnThisDevice_subtitle;
