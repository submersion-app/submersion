import 'package:flutter/material.dart';

import 'package:submersion/core/constants/summary_pane_view.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A section's in-session choice of summary view, set by the corner toggle.
///
/// Null means "follow the Appearance setting". Not autoDispose: the choice
/// lasts for the session, and a relaunch returns every pane to the default.
final summaryPaneOverrideProvider =
    StateProvider.family<SummaryPaneView?, String>((ref, sectionId) => null);

/// Shows a section's summary pane as its calm [scene] or its data-rich
/// [details], with a small corner button that flips between them.
///
/// The default comes from Settings > Appearance. A page with nothing to
/// summarise ([isEmpty]) defaults to the details, whose quick actions are a
/// new diver's way in; the toggle still works there.
class SummaryPaneSwitcher extends ConsumerWidget {
  const SummaryPaneSwitcher({
    super.key,
    required this.sectionId,
    required this.scene,
    required this.details,
    this.isEmpty = false,
  });

  /// Identifies the section whose session override this pane reads.
  final String sectionId;
  final WidgetBuilder scene;
  final WidgetBuilder details;
  final bool isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(summaryPaneOverrideProvider(sectionId));
    final setting = ref.watch(
      settingsProvider.select((s) => s.summaryPaneView),
    );
    final view = override ?? (isEmpty ? SummaryPaneView.details : setting);
    final showingScene = view == SummaryPaneView.scene;

    return Stack(
      children: [
        Positioned.fill(
          child: KeyedSubtree(
            key: ValueKey('summary-pane-${view.name}'),
            child: showingScene ? scene(context) : details(context),
          ),
        ),
        PositionedDirectional(
          top: 6,
          end: 6,
          child: SummaryPaneToggle(
            showingScene: showingScene,
            onPressed: () {
              final next = showingScene
                  ? SummaryPaneView.details
                  : SummaryPaneView.scene;
              ref.read(summaryPaneOverrideProvider(sectionId).notifier).state =
                  next;
            },
          ),
        ),
      ],
    );
  }
}

/// The small round corner button that flips a summary pane.
///
/// Drawn as a 30 px translucent disc so it reads on any scene, with a 48 px
/// hit box on every platform.
class SummaryPaneToggle extends StatelessWidget {
  const SummaryPaneToggle({
    super.key,
    required this.showingScene,
    required this.onPressed,
  });

  final bool showingScene;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      tooltip: showingScene
          ? l10n.summaryPane_toggle_showDetails
          : l10n.summaryPane_toggle_showScene,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ink.withValues(alpha: 0.10),
          border: Border.all(color: ink.withValues(alpha: 0.22)),
        ),
        child: Icon(
          showingScene ? Icons.grid_view : Icons.water,
          size: 16,
          color: ink.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
