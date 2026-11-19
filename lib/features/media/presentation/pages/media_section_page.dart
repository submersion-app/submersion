import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/pages/gear_gallery_view.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/features/media_store/presentation/pages/transfers_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';

/// The Media screen's Photos/Videos tab: owns the selected console section
/// and renders its content inside [MediaConsoleScaffold], whose section tabs
/// sit under [headerTitle], and carries out the header's Import, Transfers
/// and Sources buttons (#4587).
///
/// It also owns the Library's selection, so the Library toolbar can sit in
/// the header's tab row at desktop widths and still drive the grid below
/// (#4777).
class MediaSectionPage extends ConsumerStatefulWidget {
  const MediaSectionPage({
    super.key,
    required this.headerTitle,
    this.importPickOverride,
  });

  /// The header's title: the Media screen's Photos/Videos and Documents
  /// switch (#3631).
  final SectionHeaderTitle headerTitle;

  /// Test seam: returns the picked assets instead of driving the platform
  /// picker (which flutter_test cannot).
  @visibleForTesting
  final Future<List<AssetInfo>> Function(BuildContext context)?
  importPickOverride;

  @override
  ConsumerState<MediaSectionPage> createState() => _MediaSectionPageState();
}

class _MediaSectionPageState extends ConsumerState<MediaSectionPage> {
  MediaConsoleSection _section = MediaConsoleSection.library;

  /// The Library's bulk selection, held here rather than in the Library view
  /// because at desktop widths its toolbar, Select button included, sits in
  /// the header's tab row (#4777). It lasts as long as the Library section
  /// stays selected: a resize that remounts the view keeps it, and [_select]
  /// ends it when another section takes the page.
  final SelectionController _librarySelection = SelectionController();

  // Built once: the page reads the screen size to place the toolbar, so it
  // rebuilds on every resize frame and every new missing-file count. The
  // same instances let Flutter skip the Library, whose build walks every
  // loaded row, rather than re-running it each time.
  late final Widget _libraryWithToolbar = MediaLibraryView(
    selection: _librarySelection,
  );
  late final Widget _libraryUnderHeader = MediaLibraryView(
    selection: _librarySelection,
    showToolbar: false,
  );
  late final Widget _headerToolbar = MediaLibraryHeaderToolbar(
    selection: _librarySelection,
    keyboardScope: true,
  );

  @override
  void dispose() {
    _librarySelection.dispose();
    super.dispose();
  }

  /// Shows [section]. Leaving the Library ends its selection, so a bulk
  /// action never reaches rows the user can no longer see.
  void _select(MediaConsoleSection section) {
    if (section == _section) return;
    if (_section == MediaConsoleSection.library) _librarySelection.exit();
    setState(() => _section = section);
  }

  @override
  void initState() {
    super.initState();
    // Opportunistic watcher pass, gated to once a day inside the provider:
    // the console is the app's stand-in for a startup hook.
    //
    // Kicked from initState behind a post-frame callback, NOT from build().
    // The pass walks every watched root recursively, and hanging that off a
    // build meant it started while the section was still laying out (#1182).
    // After the frame, the console is on screen before any filesystem work
    // begins, and the guard inside WatcherAutoScan keeps a remount from
    // starting a second overlapping pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(watcherAutoScanProvider).kick();
    });
  }

  /// True from a button tap until what it opened has closed.
  bool _actionOpen = false;

  /// Runs one tab-row button, ignoring taps while an earlier one is still
  /// open. A pushed page covers the buttons, but a desktop file dialog is no
  /// route, so a second Import tap would otherwise start a second import.
  Future<void> _onAction(MediaConsoleAction action) async {
    if (_actionOpen) return;
    _actionOpen = true;
    try {
      await _runAction(action);
    } finally {
      _actionOpen = false;
    }
  }

  Future<void> _runAction(MediaConsoleAction action) async {
    switch (action) {
      case MediaConsoleAction.importMedia:
        await MediaImportView.launchImport(
          context,
          ref,
          pick: widget.importPickOverride,
        );
      case MediaConsoleAction.transfers:
        // Settings calls the same page Uploads; from here it takes the
        // button's name.
        final title = context.l10n.media_console_transfers;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TransfersPage(title: title)),
        );
      case MediaConsoleAction.sources:
        // Browsing a source filters the Library and closes the page with
        // true: show the Library it filtered, whichever tab was up.
        final browsed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const MediaSourcesSectionPage()),
        );
        if (browsed == true && mounted) {
          _select(MediaConsoleSection.library);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Missing files live under the Library's health chip; the badge on the
    // Library tab is how a broken file gets noticed from another section.
    final missingCount = ref.watch(missingCountProvider).value ?? 0;
    final library = _section == MediaConsoleSection.library;
    // At desktop widths the Library's toolbar joins the tab row instead of
    // taking a row of its own under the header (#4777).
    final toolbarInHeader = MediaConsoleScaffold.hostsTabRowTrailing(context);

    return MediaConsoleScaffold(
      headerTitle: widget.headerTitle,
      selected: _section,
      onSelect: _select,
      onAction: _onAction,
      badgeCounts: {MediaConsoleSection.library: missingCount},
      tabRowTrailing: library ? _headerToolbar : null,
      child: switch (_section) {
        MediaConsoleSection.library =>
          toolbarInHeader ? _libraryUnderHeader : _libraryWithToolbar,
        MediaConsoleSection.gear => const GearGalleryView(),
      },
    );
  }
}
