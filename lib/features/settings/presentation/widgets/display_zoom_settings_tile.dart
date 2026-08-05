import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-wide display zoom control.
///
/// No preview widget: zoom is applied at the app root, so this settings page
/// scales as the slider moves and is itself the live preview.
class DisplayZoomSettingsTile extends ConsumerWidget {
  const DisplayZoomSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(displayZoomNotifierProvider);
    final notifier = ref.read(displayZoomNotifierProvider.notifier);
    final l10n = context.l10n;
    final percent = (zoom * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text(l10n.settings_appearance_displaySize),
          subtitle: Text(l10n.settings_appearance_displaySize_value(percent)),
          trailing: zoom == DisplayZoom.defaultValue
              ? null
              : TextButton(
                  onPressed: notifier.reset,
                  child: Text(l10n.settings_appearance_displaySize_reset),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                l10n.settings_appearance_displaySize_smaller,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Expanded(
                child: Slider(
                  value: zoom,
                  min: DisplayZoom.min,
                  max: DisplayZoom.max,
                  divisions: DisplayZoom.divisions,
                  label: l10n.settings_appearance_displaySize_value(percent),
                  // Rescale live on every notch, but only write to storage
                  // once the drag ends.
                  onChanged: notifier.previewZoom,
                  onChangeEnd: notifier.setZoom,
                ),
              ),
              Text(
                l10n.settings_appearance_displaySize_larger,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
