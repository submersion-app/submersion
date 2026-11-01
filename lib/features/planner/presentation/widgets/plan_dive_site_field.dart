import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where the selected dive is planned (issue #3565), optional. The planner
/// does not use it; a dive logged from the plan takes it.
class PlanDiveSiteField extends ConsumerWidget {
  const PlanDiveSiteField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final siteId = ref.watch(divePlanNotifierProvider.select((s) => s.siteId));
    final sites = ref.watch(sitesProvider).value ?? const [];
    final site = sites.where((s) => s.id == siteId).firstOrNull;

    return InkWell(
      key: const Key('diveSiteField'),
      onTap: () => _pick(context, ref, siteId),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: l10n.plannerSeries_site,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: const Icon(Icons.location_on_outlined),
          suffixIcon: siteId == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.plannerSeries_site_clear,
                  onPressed: () => ref
                      .read(divePlanNotifierProvider.notifier)
                      .updateSite(null),
                ),
        ),
        child: Text(
          site?.name ?? l10n.plannerSeries_site_none,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final result = await showSitePicker(
      context,
      selectedSiteId: current,
      allowClear: true,
      // Planning a dive is no reason to ask where the diver is now.
      useDeviceLocation: false,
    );
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    switch (result) {
      case SitePicked(:final site):
        notifier.updateSite(site.id);
      case SitePickerCleared():
        notifier.updateSite(null);
      case SitePickerCreateRequested() || null:
        break;
    }
  }
}
