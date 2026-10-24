import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/features/media_store/presentation/widgets/transfers_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';

/// Top-level Media section host: owns the selected console section and
/// renders its content inside [MediaConsoleScaffold] (tabs in the app bar,
/// inline beside the title when they fit).
class MediaSectionPage extends ConsumerStatefulWidget {
  const MediaSectionPage({super.key, this.headerTitle});

  /// Replaces the plain "Media" title with the Media and Documents tab
  /// switch, as Training's tab switch does on its own tabs (#3631).
  final SectionHeaderTitle? headerTitle;

  @override
  ConsumerState<MediaSectionPage> createState() => _MediaSectionPageState();
}

/// The width [text] renders at in [style], on one line, at the context's
/// text scale. Stands in for [headerTitle]'s own pre-measured width when
/// there is no header title (a standalone Media page outside the Media and
/// Documents host), where the title stays a plain string.
double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

class _MediaSectionPageState extends ConsumerState<MediaSectionPage> {
  MediaConsoleSection _section = MediaConsoleSection.library;

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

  @override
  Widget build(BuildContext context) {
    // Missing files live under the Library's health chip; the badge on the
    // Library tab is how a broken file gets noticed from another section.
    final missingCount = ref.watch(missingCountProvider).value ?? 0;
    final headerTitle = widget.headerTitle;
    final title =
        headerTitle?.build(context, SectionHeaderSlot.appBar, null) ??
        Text(context.l10n.nav_media);
    final titleWidth =
        headerTitle?.appBarTitleWidth?.call(context) ??
        _measureTextWidth(
          context,
          context.l10n.nav_media,
          Theme.of(context).appBarTheme.titleTextStyle ??
              Theme.of(context).textTheme.titleLarge ??
              const TextStyle(),
        );

    return MediaConsoleScaffold(
      title: title,
      titleWidth: titleWidth,
      toolbarHeight: headerTitle?.appBarHeight(context, null),
      appBarPin: headerTitle?.pinAppBar,
      selected: _section,
      onSelect: (section) => setState(() => _section = section),
      badgeCounts: {MediaConsoleSection.library: missingCount},
      child: switch (_section) {
        MediaConsoleSection.library => const MediaLibraryView(),
        MediaConsoleSection.sources => MediaSourcesSectionView(
          onBrowseSource: () =>
              setState(() => _section = MediaConsoleSection.library),
        ),
        MediaConsoleSection.transfers => const TransfersView(),
        MediaConsoleSection.importMedia => const MediaImportView(),
      },
    );
  }
}
