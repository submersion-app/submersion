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

/// Every status light as a wrap of full-size pills, alerts first: what the
/// phone's status strip opens when the diver taps its "all clear" count.
class HomeStatusLightsWrap extends ConsumerWidget {
  const HomeStatusLightsWrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaugesAsync = ref.watch(dashboardGaugesProvider);
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenHomeChips));
    return gaugesAsync.when(
      data: (g) {
        final lights = buildHomeStatusLights(context, ref, g, hidden);
        if (lights.isEmpty) return const SizedBox.shrink();
        // The same order as the header and the phone strip.
        // No run spacing: each pill's 44-point tap height already spaces
        // the rows.
        return Wrap(
          spacing: 8,
          children: [
            for (final light in orderLightsBySeverity(lights))
              HomeLightChip(light),
          ],
        );
      },
      loading: () => const SizedBox(height: 40),
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: HomeLightChip(
          HomeStatusLight(
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
