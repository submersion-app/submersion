import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Apple Health switches (issue #637): automatic import of Apple Watch
/// dives, and heart rate, recovery and sleep on dives. iOS only; each asks
/// Health for what it reads when turned on, and names the diver it belongs
/// to, who stays its diver if the app switches profiles.
class AppleHealthSettingsSection extends ConsumerWidget {
  const AppleHealthSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // defaultTargetPlatform (not dart:io) so widget tests can override it.
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final settings = ref.watch(healthSettingsProvider);
    final divers = ref.watch(allDiversProvider).value ?? const [];
    String? nameOf(String? id) =>
        divers.where((d) => d.id == id).firstOrNull?.name;

    Future<void> toggle({required bool metrics, required bool on}) async {
      final notifier = ref.read(healthSettingsProvider.notifier);
      if (!on) {
        await (metrics
            ? notifier.disableMetrics()
            : notifier.disableAutoImport());
        return;
      }
      final diverId = ref.read(currentDiverIdProvider);
      final health = ref.read(healthImportServiceProvider);
      if (diverId == null || health == null) return;
      final completed = metrics
          ? await health.requestMetricsPermissions()
          : await health.requestPermissions();
      if (!completed) return;
      await (metrics
          ? notifier.enableMetrics(diverId)
          : notifier.enableAutoImport(diverId));
    }

    Widget subtitle(String text, String? boundDiverId) {
      final name = nameOf(boundDiverId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (boundDiverId != null && name != null)
            Text(l10n.settings_appleHealth_boundDiver(name)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.watch),
              value: settings.autoImportDiverId != null,
              title: Text(l10n.settings_appleHealth_autoImport_title),
              subtitle: subtitle(
                l10n.settings_appleHealth_autoImport_subtitle,
                settings.autoImportDiverId,
              ),
              onChanged: (on) => toggle(metrics: false, on: on),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.monitor_heart_outlined),
              value: settings.metricsDiverId != null,
              title: Text(l10n.settings_appleHealth_metrics_title),
              subtitle: subtitle(
                l10n.settings_appleHealth_metrics_subtitle,
                settings.metricsDiverId,
              ),
              onChanged: (on) => toggle(metrics: true, on: on),
            ),
          ],
        ),
      ),
    );
  }
}
