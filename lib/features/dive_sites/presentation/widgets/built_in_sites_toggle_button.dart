import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';

/// Toggle button for showing/hiding built-in dive site markers on the map.
class BuiltInSitesToggleButton extends ConsumerWidget {
  const BuiltInSitesToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showBuiltInSitesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: show
          ? context.l10n.diveSites_map_builtInSites_on
          : context.l10n.diveSites_map_builtInSites_off,
      toggled: show,
      child: IconButton(
        icon: Icon(
          show ? Icons.public : Icons.public_off,
          color: show ? colorScheme.primary : null,
        ),
        tooltip: show
            ? context.l10n.diveSites_map_builtInSites_hide
            : context.l10n.diveSites_map_builtInSites_show,
        onPressed: () =>
            ref.read(showBuiltInSitesProvider.notifier).state = !show,
      ),
    );
  }
}
