import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_advanced_section.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_status_line.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_upload_settings.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_using_row.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Photos & videos (spec section 8.3): where copies are kept and what is
/// true of them, how uploads run, where photos come from, then Advanced.
/// It replaces the Photos & Media hub and the Media Storage page.
class PhotosVideosPage extends ConsumerStatefulWidget {
  const PhotosVideosPage({super.key});

  /// This page's route: the media store setup items resolve here.
  static const route = '/settings/photos-media';

  @override
  ConsumerState<PhotosVideosPage> createState() => _PhotosVideosPageState();
}

class _PhotosVideosPageState extends ConsumerState<PhotosVideosPage> {
  /// The Using row, whose Set up / Change is what resolves the media store
  /// items the pending setup card lists on this page.
  final _usingRowKey = GlobalKey();

  void _showUsingRow() {
    final usingRow = _usingRowKey.currentContext;
    if (usingRow == null) return;
    Scrollable.ensureVisible(
      usingRow,
      duration: const Duration(milliseconds: 250),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final attached = ref.watch(photosCopiesProvider).value?.attached ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_photosVideos_title),
        actions: [
          // Until the Set up this device card replaces it (phase 6).
          IconButton(
            tooltip: l10n.settings_photosMedia_guidedSetup,
            icon: const Icon(Icons.checklist_outlined),
            onPressed: () =>
                context.pushSettingsPage('/settings/photos-media/setup'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // A media item opens this very page: point at the Using row
          // instead of stacking another copy of it.
          PendingSetupCard(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            hostRoute: PhotosVideosPage.route,
            onHostRoute: _showUsingRow,
          ),
          _header(context, l10n.settings_photos_cloudHeader),
          KeyedSubtree(key: _usingRowKey, child: const PhotosUsingRow()),
          const PhotosStatusLine(),
          // Keyed, like the Advanced section below: the list matches its
          // children by key, so attaching or detaching (which adds or drops
          // this row) cannot hand a later sibling's State to another.
          if (attached)
            const PhotosUploadSettings(key: ValueKey('photos-upload-settings')),
          _header(context, l10n.settings_photos_sourcesHeader),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.settings_photos_library),
            subtitle: Text(l10n.settings_photosMedia_photoSources_subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushSettingsPage('/settings/media-sources'),
          ),
          // Its State holds any export, verify or backfill in flight, which
          // must survive the upload settings above appearing or going.
          PhotosAdvancedSection(
            key: const ValueKey('photos-advanced-section'),
            attached: attached,
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: buildSettingsSectionHeader(context, text),
  );
}
