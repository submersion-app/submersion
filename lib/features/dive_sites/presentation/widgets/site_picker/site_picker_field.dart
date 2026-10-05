import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Identifies the field's tap target, for tests.
const sitePickerFieldKey = Key('site-picker-field');

/// A dive filter's site field: shows the selected site (or "All sites") and
/// opens the shared site picker sheet on tap (#1080).
///
/// The value is always a site id or null. An id whose site has been deleted
/// shows "All sites", but keeps the clear button, since the filter still
/// applies until it is cleared.
class SitePickerField extends ConsumerWidget {
  const SitePickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showSitePicker(
      context,
      selectedSiteId: value,
      allowClear: true,
      // Opening a filter never prompts for location permission.
      useDeviceLocation: false,
    );
    switch (result) {
      case SitePicked(:final site):
        onChanged(site.id);
      case SitePickerCleared():
        onChanged(null);
      case SitePickerCreateRequested() || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sites = ref.watch(sitesProvider).value ?? const [];
    final site = sites.where((s) => s.id == value).firstOrNull;
    final location = site?.locationString ?? '';

    return InkWell(
      key: sitePickerFieldKey,
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.diveLog_search_label_diveSite,
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.diveLog_filter_clearSite,
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(site?.name ?? l10n.diveLog_filter_allSites),
            if (location.isNotEmpty)
              Text(
                location,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
