import 'package:flutter/material.dart';

import 'package:submersion/features/media/presentation/pages/media_sources_section_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Media section's Sources screen as a page of its own, opened from the
/// Sources button on the section's tab row (#4587): browse by source, and the
/// folders the repair watcher keeps an eye on.
///
/// Push it with `Navigator.push<bool>`. Browsing a source sets the Library's
/// filter and closes the page with `true`, so the opener can show the Library
/// it filtered; closing it any other way gives no result.
class MediaSourcesSectionPage extends StatelessWidget {
  const MediaSourcesSectionPage({super.key, this.pickFolderOverride});

  /// Test seam for the platform directory picker.
  @visibleForTesting
  final Future<String?> Function()? pickFolderOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.media_console_sources)),
      body: MediaSourcesSectionView(
        onBrowseSource: () => Navigator.of(context).pop(true),
        pickFolderOverride: pickFolderOverride,
      ),
    );
  }
}
