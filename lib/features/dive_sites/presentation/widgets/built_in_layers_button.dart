import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_kind_glyph.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Sites map's control for its built-in catalogue layers: a button
/// that opens a menu with one tick per layer.
///
/// The menu stays open while a row is ticked, so both layers can be set
/// in one visit. The button shows whether any built-in record is drawn.
class BuiltInLayersButton extends ConsumerStatefulWidget {
  const BuiltInLayersButton({super.key});

  @override
  ConsumerState<BuiltInLayersButton> createState() =>
      _BuiltInLayersButtonState();
}

class _BuiltInLayersButtonState extends ConsumerState<BuiltInLayersButton> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(builtInMapLayersNotifierProvider);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    Widget row(CatalogueKind kind, String label) => CheckboxMenuButton(
      key: ValueKey('builtInLayer_${kind.name}'),
      value: layers.shows(kind),
      closeOnActivate: false,
      onChanged: (on) => ref
          .read(builtInMapLayersNotifierProvider.notifier)
          .setLayer(kind, on ?? false),
      trailingIcon: Icon(catalogueKindIcon(kind), size: 20),
      child: Text(label),
    );

    return MenuAnchor(
      controller: _menu,
      menuChildren: [
        row(CatalogueKind.site, l10n.diveSites_map_layers_diveSites),
        row(CatalogueKind.register, l10n.diveSites_map_layers_registers),
      ],
      // The icon says whether any built-in site is drawn; so does the
      // toggled state, for a screen reader that cannot see the icon.
      child: Semantics(
        toggled: layers.any,
        child: IconButton(
          icon: Icon(
            layers.any ? Icons.public : Icons.public_off,
            color: layers.any ? colorScheme.primary : null,
          ),
          tooltip: l10n.diveSites_map_layers_tooltip,
          onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
        ),
      ),
    );
  }
}
