import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The species map's own layers control: the public records switch and the
/// expected-species scope (issue #4358).
///
/// Styled like `MapStyleButton` so it stacks with the map corner controls.
class SpeciesMapLayersButton extends ConsumerWidget {
  const SpeciesMapLayersButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final publicOn = ref.watch(speciesMapPublicLayerProvider);
    final scope = ref.watch(speciesMapExpectedScopeProvider);

    Widget scopeTile(ExpectedSiteScope value, String label) {
      final selected = scope == value;
      return ListTile(
        key: ValueKey('species_map_scope_${value.name}'),
        dense: true,
        selected: selected,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
        title: Text(label),
        onTap: () =>
            ref.read(speciesMapExpectedScopeProvider.notifier).set(value),
      );
    }

    return MenuAnchor(
      menuChildren: [
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                key: const ValueKey('species_map_public_toggle'),
                value: publicOn,
                title: Text(l10n.speciesMap_layers_public),
                subtitle: Text(l10n.speciesMap_layers_publicHint),
                onChanged: (on) =>
                    ref.read(speciesMapPublicLayerProvider.notifier).set(on),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l10n.speciesMap_layers_expectedHeading,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              scopeTile(
                ExpectedSiteScope.mine,
                l10n.speciesMap_layers_scopeMine,
              ),
              scopeTile(
                ExpectedSiteScope.allVisible,
                l10n.speciesMap_layers_scopeAllVisible,
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, _) => Material(
        color: scheme.surface,
        elevation: 2,
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Tooltip(
            message: l10n.speciesMap_layers_tooltip,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                publicOn ? Icons.travel_explore : Icons.filter_list,
                size: 22,
                color: publicOn ? scheme.primary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
