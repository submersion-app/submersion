import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/panels/key_numbers_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which numbers the key numbers panel at the top of Home shows.
class HomeKeyNumbersPage extends ConsumerWidget {
  const HomeKeyNumbersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hidden = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeKeyNumbers),
    );
    final enabled = KeyNumbersPanel.enabledTiles(hidden);
    final lane = ref.watch(homeSacLaneProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_homePanels_keyNumbers)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.settings_homeKeyNumbers_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final tile in HomeKeyNumber.values)
            SwitchListTile(
              key: Key('homeKeyNumberToggle_${tile.name}'),
              title: Text(homeKeyNumberLabel(l10n, tile, lane: lane)),
              value: enabled.contains(tile),
              onChanged: (on) {
                // Saved as the full hidden set, so the defaults stop
                // applying the first time the diver changes anything.
                final next = {
                  for (final t in HomeKeyNumber.values)
                    if (t == tile ? !on : !enabled.contains(t)) t.name,
                };
                notifier.setHiddenHomeKeyNumbers(next);
              },
            ),
        ],
      ),
    );
  }
}
