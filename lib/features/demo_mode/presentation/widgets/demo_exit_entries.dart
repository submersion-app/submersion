/// The ways out of demo mode beside the corner ribbon (issue #4428), which is
/// only a label (issue #4436): a card heading the dashboard, a button at the
/// foot of the navigation rail, and a tile heading the phone's More sheet.
/// Each is nothing at all while demo mode is off, and each asks before
/// leaving.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_confirm.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A card at the top of the dashboard saying demo mode is on, with the way
/// out.
class DemoModeDashboardCard extends ConsumerWidget {
  const DemoModeDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(demoModeActiveProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card.filled(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                Icons.explore_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              // Text and button share a line when they fit and stack when a
              // narrow window or large text would squeeze the text.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.demo_active_label,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          l10n.demo_card_body,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => confirmAndExitDemo(context, ref),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.demo_exit_button),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way out at the foot of the navigation rail, for its `trailing` slot
/// with `trailingAtBottom`: an icon with a tooltip while the rail is
/// collapsed, and the icon with its label once the rail has opened.
class DemoExitRailButton extends ConsumerWidget {
  const DemoExitRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(demoModeActiveProvider)) return const SizedBox.shrink();
    final label = context.l10n.demo_exit_button;
    void exit() => confirmAndExitDemo(context, ref);
    // The rail's width animates between its collapsed and extended sizes.
    // The label only appears once the rail is fully open, so the button never
    // asks for more width than the rail has on the way.
    final extended = NavigationRail.extendedAnimation(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: AnimatedBuilder(
        animation: extended,
        builder: (context, _) => extended.value == 1
            ? TextButton.icon(
                onPressed: exit,
                icon: const Icon(Icons.logout),
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : IconButton(
                onPressed: exit,
                tooltip: label,
                icon: const Icon(Icons.logout),
              ),
      ),
    );
  }
}

/// The way out heading the phone's More sheet. [onTap] belongs to the sheet's
/// owner: it closes the sheet and asks from a context that outlives it.
class DemoExitSheetTile extends ConsumerWidget {
  const DemoExitSheetTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(demoModeActiveProvider)) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.logout),
      title: Text(context.l10n.demo_exit_button),
      onTap: onTap,
    );
  }
}
