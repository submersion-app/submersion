import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/backup/presentation/pages/backup_settings_page.dart';
import 'package:submersion/features/backup/presentation/pages/unrecognized_backups_page.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_settings_page.dart';
import 'package:submersion/features/maps/presentation/pages/offline_maps_page.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_page.dart';
import 'package:submersion/features/media/presentation/pages/network_sources_page.dart';
import 'package:submersion/features/media_store/presentation/pages/media_storage_page.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/features/settings/presentation/pages/data_tools_page.dart';
import 'package:submersion/features/settings/presentation/pages/import_options_page.dart';
import 'package:submersion/features/settings/presentation/pages/cloud_sync_page.dart';
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/pages/data_section_content.dart';
import 'package:submersion/features/settings/presentation/pages/fix_dive_times_page.dart';
import 'package:submersion/features/settings/presentation/pages/lightroom_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/link_buddy_names_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_setup_page.dart';
import 'package:submersion/features/settings/presentation/pages/retype_other_gear_page.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/pages/storage_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/storage_usage_page.dart';
import 'package:submersion/features/settings/presentation/pages/webdav_config_page.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/shared_library/presentation/pages/change_library_connection_page.dart';
import 'package:submersion/features/shared_library/presentation/pages/connect_shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/pages/library_backups_page.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_libraries_page.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_library_members_page.dart';
import 'package:submersion/features/shared_library/presentation/pages/shared_library_page.dart';
import 'package:submersion/features/shared_library/presentation/pages/suggestion_inbox_page.dart';

/// Settings > Data inside the desktop detail pane: the Data hub, with every
/// page reached from it opening in the pane too (issue #3467).
///
/// `/settings?selected=data` is the hub, and each `&dataPage=<path>` stacks
/// the page at `/settings/<path>` on top of it.
class DataSettingsPane extends StatelessWidget {
  const DataSettingsPane({super.key});

  /// The query parameter holding the open pages, outermost first.
  static const queryParam = 'dataPage';

  @override
  Widget build(BuildContext context) => const SettingsPaneNavigator(
    sectionId: 'data',
    queryParam: queryParam,
    hub: DataSectionContent(),
    pageFor: dataPanePage,
  );
}

/// The page the Data pane shows for [location], or null when it is not a page
/// reached from Settings > Data.
///
/// Mirrors these pages' routes in `app_router.dart`; a test there checks that
/// each location builds the same page both ways.
Widget? dataPanePage(Uri location) {
  final segments = location.pathSegments;
  if (segments.isEmpty || segments.first != 'settings') return null;
  return switch (segments.sublist(1)) {
    ['backup'] => const BackupSettingsPage(),
    ['cloud-sync'] => const CloudSyncPage(),
    ['cloud-sync', 's3-config'] => const S3ConfigPage(),
    ['cloud-sync', 'webdav-config'] => const WebDavConfigPage(),
    ['shared-libraries'] => const SharedLibrariesPage(),
    ['shared-libraries', 'connect'] => ConnectSharedLibraryPage(
      initialPrefix: location.queryParameters['prefix'],
    ),
    ['shared-libraries', final id] => SharedLibraryPage(libraryId: id),
    ['shared-libraries', final id, 'members'] => SharedLibraryMembersPage(
      libraryId: id,
    ),
    ['shared-libraries', final id, 'suggestions'] => SuggestionInboxPage(
      libraryId: id,
    ),
    ['shared-libraries', final id, 'backups'] => LibraryBackupsPage(
      libraryId: id,
    ),
    ['shared-libraries', final id, 'connection'] => ChangeLibraryConnectionPage(
      libraryId: id,
    ),
    ['photos-media'] => const PhotosMediaHubPage(),
    ['photos-media', 'setup'] => const PhotosMediaSetupPage(),
    ['media-sources'] => const MediaSourcesPage(),
    ['media-sources', 'network-sources'] => const NetworkSourcesPage(),
    // Hidden pending Adobe review; while it is, the route redirects to Media
    // Sources, so a push is left to the router.
    ['lightroom'] when lightroomUiEnabled => const LightroomSettingsPage(),
    ['media-storage'] => const MediaStoragePage(),
    ['media-storage', 'transfers'] => const TransfersPage(),
    ['connected-accounts'] => const ConnectedAccountsPage(),
    ['storage'] => const StorageSettingsPage(),
    ['storage-usage'] => const StorageUsagePage(),
    ['storage-usage', 'unrecognized-backups'] =>
      const UnrecognizedBackupsPage(),
    ['offline-maps'] => const OfflineMapsPage(),
    ['import-options'] => const ImportOptionsPage(),
    ['data-tools'] => const DataToolsPage(),
    ['fix-dive-times'] => const FixDiveTimesPage(),
    ['link-buddy-names'] => const LinkBuddyNamesPage(),
    ['retype-other-gear'] => const RetypeOtherGearPage(),
    ['data-quality'] => const DataQualitySettingsPage(),
    _ => null,
  };
}
