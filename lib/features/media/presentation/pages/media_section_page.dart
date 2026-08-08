import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/pages/media_missing_view.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_view.dart';
import 'package:submersion/features/media/presentation/pages/media_unlinked_inbox_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/features/media_store/presentation/widgets/transfers_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Top-level Media section host: owns the selected console section and
/// renders its content inside [MediaConsoleScaffold] (sidebar on desktop,
/// tabs on phone).
class MediaSectionPage extends ConsumerStatefulWidget {
  const MediaSectionPage({super.key});

  @override
  ConsumerState<MediaSectionPage> createState() => _MediaSectionPageState();
}

class _MediaSectionPageState extends ConsumerState<MediaSectionPage> {
  MediaConsoleSection _section = MediaConsoleSection.library;

  @override
  Widget build(BuildContext context) {
    // Opportunistic watcher pass, gated to once a day inside the
    // provider: the console is the app's stand-in for a startup hook.
    ref.watch(watcherAutoScanProvider);
    final unlinkedCount = ref.watch(unlinkedCountProvider).value ?? 0;
    final missingCount = ref.watch(missingCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nav_media)),
      body: MediaConsoleScaffold(
        selected: _section,
        onSelect: (section) => setState(() => _section = section),
        badgeCounts: {
          MediaConsoleSection.unlinked: unlinkedCount,
          MediaConsoleSection.missing: missingCount,
        },
        child: switch (_section) {
          MediaConsoleSection.library => const MediaLibraryView(),
          MediaConsoleSection.unlinked => const MediaUnlinkedInboxView(),
          MediaConsoleSection.missing => const MediaMissingView(),
          MediaConsoleSection.sources => MediaSourcesSectionView(
            onBrowseSource: () =>
                setState(() => _section = MediaConsoleSection.library),
          ),
          MediaConsoleSection.transfers => const TransfersView(),
          MediaConsoleSection.importMedia => const MediaImportView(),
        },
      ),
    );
  }
}
