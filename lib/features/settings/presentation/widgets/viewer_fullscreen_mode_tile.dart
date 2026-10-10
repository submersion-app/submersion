import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/settings/presentation/providers/viewer_fullscreen_mode_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the fullscreen dive profile and media viewers fill the window or
/// take the whole screen (#3178).
///
/// Desktop only: on phones and tablets those viewers already hide the system
/// bars, so the choice would change nothing there.
class ViewerFullscreenModeTile extends ConsumerWidget {
  const ViewerFullscreenModeTile({super.key});

  static bool get isSupported => hasDesktopWindow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(viewerFullscreenModeProvider);

    return ListTile(
      leading: const Icon(Icons.fullscreen),
      title: Text(l10n.settings_appearance_viewerFullscreen),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_appearance_viewerFullscreen_subtitle),
          const SizedBox(height: 8),
          SegmentedButton<ViewerFullscreenMode>(
            segments: [
              ButtonSegment(
                value: ViewerFullscreenMode.fullWindow,
                label: Text(l10n.settings_appearance_viewerFullscreen_window),
              ),
              ButtonSegment(
                value: ViewerFullscreenMode.fullscreen,
                label: Text(l10n.settings_appearance_viewerFullscreen_screen),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => ref
                .read(viewerFullscreenModeProvider.notifier)
                .setMode(selection.first),
          ),
        ],
      ),
    );
  }
}
