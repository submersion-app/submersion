import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

String lensLabel(AppLocalizations l10n, ConnectionLens lens) =>
    switch (lens.id) {
      'circle' => l10n.connections_lens_circle,
      'where' => l10n.connections_lens_where,
      _ => lens.id,
    };

class LensChipRow extends ConsumerWidget {
  const LensChipRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(connectionsLensProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          for (final lens in ConnectionLens.phase1)
            ChoiceChip(
              label: Text(lensLabel(context.l10n, lens)),
              selected: active.lensId == lens.id,
              onSelected: (_) {
                ref.read(connectionsFocusProvider.notifier).state = null;
                ref.read(connectionsSelectionProvider.notifier).state = null;
                ref
                    .read(connectionsLensProvider.notifier)
                    .select(LensSelection.lens(lens));
              },
            ),
        ],
      ),
    );
  }
}
