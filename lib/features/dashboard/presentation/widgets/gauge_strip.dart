import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_light_chip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart'
    show
        kBackupAlertDays,
        kBackupWarnDays,
        kCurrencyAlertDays,
        kCurrencyWarnDays;

/// The old Home's status chips, drawn from the status-light models. Kept
/// until the new Home replaces the page that shows it.
class GaugeStrip extends ConsumerWidget {
  const GaugeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenHomeChips));
    return gaugesAsync.when(
      data: (g) {
        final lights = buildHomeStatusLights(context, ref, g, hidden);
        if (lights.isEmpty) return const SizedBox.shrink();
        // Alert chips lead; everything else keeps its declaration order.
        final ordered = [for (var i = 0; i < lights.length; i++) (i, lights[i])]
          ..sort((a, b) {
            int key(HomeStatusLight l) => l.tone == HomeLightTone.alert ? 0 : 1;
            final byTone = key(a.$2) - key(b.$2);
            return byTone != 0 ? byTone : a.$1 - b.$1;
          });
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final e in ordered) HomeLightChip(e.$2)],
        );
      },
      loading: () => const SizedBox(height: 40),
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: HomeLightChip(
          HomeStatusLight(
            type: HomeChipType.sync,
            icon: Icons.refresh,
            label: context.l10n.dashboard_gauges_retry,
            tone: HomeLightTone.neutral,
            onTap: () => ref.invalidate(dashboardGaugesProvider),
          ),
        ),
      ),
    );
  }
}
