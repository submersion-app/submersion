import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/settings/presentation/providers/media_cache_settings_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A cache size as the sliders show it: whole megabytes below a gigabyte,
/// whole gigabytes from there. Every stop is one or the other.
///
/// The suffixes are not localized, as nowhere else in the app (see
/// `formatBytes`), and a byte is not one of the diver's unit settings.
String formatMediaCacheSize(int mb) =>
    mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB';

/// The two media cache sizes (issue #3337): decoded images in memory, and
/// thumbnails on disk. Each is a slider over fixed stops.
class MediaCacheSettingsCard extends ConsumerWidget {
  const MediaCacheSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(mediaCacheSettingsProvider);
    final notifier = ref.read(mediaCacheSettingsProvider.notifier);

    // The same style as Test Connection on the network settings page.
    Widget emptyButton({Key? key, VoidCallback? onPressed}) =>
        OutlinedButton.icon(
          key: key,
          onPressed: onPressed,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(l10n.settings_mediaCache_disk_empty),
        );

    return Card(
      child: Column(
        children: [
          _CacheSizeSlider(
            sliderKey: const ValueKey('media_memory_cache_slider'),
            icon: Icons.memory_outlined,
            title: l10n.settings_mediaCache_memory_title,
            subtitle: l10n.settings_mediaCache_memory_subtitle,
            steps: kMemoryCacheStepsMb,
            valueMb: settings.memoryCacheMb,
            onChanged: notifier.setMemoryCacheMb,
            // Nothing to empty here, but the two sliders should be the same
            // width. An unseen copy of the disk row's button holds exactly
            // its space, whatever the label's length in this language.
            trailing: ExcludeSemantics(
              child: Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: emptyButton(),
              ),
            ),
          ),
          const Divider(height: 1),
          _CacheSizeSlider(
            sliderKey: const ValueKey('media_disk_cache_slider'),
            icon: Icons.sd_storage_outlined,
            title: l10n.settings_mediaCache_disk_title,
            subtitle: l10n.settings_mediaCache_disk_subtitle,
            steps: kDiskCacheStepsMb,
            valueMb: settings.diskCacheMb,
            onChanged: notifier.setDiskCacheMb,
            trailing: emptyButton(
              key: const ValueKey('media_disk_cache_empty_button'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final emptied = await notifier.emptyDiskCache();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        emptied
                            ? l10n.settings_mediaCache_disk_emptied
                            : l10n.settings_mediaCache_disk_emptyFailed,
                      ),
                    ),
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheSizeSlider extends StatefulWidget {
  const _CacheSizeSlider({
    required this.sliderKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.valueMb,
    required this.onChanged,
    this.trailing,
  });

  final Key sliderKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<int> steps;
  final int valueMb;
  final Future<void> Function(int mb) onChanged;

  /// Shown to the right of the slider.
  final Widget? trailing;

  @override
  State<_CacheSizeSlider> createState() => _CacheSizeSliderState();
}

class _CacheSizeSliderState extends State<_CacheSizeSlider> {
  /// The stop under the thumb while it is being dragged, null otherwise.
  ///
  /// The size is committed on release only. Every stop passed on the way
  /// would otherwise be stored and, for the disk cache, evicted to at once:
  /// dragging past 256 MB and back would already have deleted the
  /// thumbnails above it.
  int? _draggingMb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.steps;
    final shownMb = _draggingMb ?? widget.valueMb;
    final size = formatMediaCacheSize(shownMb);
    // The slider runs over stop indices, not megabytes: the stops double,
    // so equal megabytes would crowd the small sizes into one end.
    final index = steps.indexOf(shownMb).clamp(0, steps.length - 1);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(widget.icon),
            title: Text(widget.title),
            subtitle: Text(widget.subtitle),
            trailing: Text(size, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    key: widget.sliderKey,
                    min: 0,
                    max: (steps.length - 1).toDouble(),
                    divisions: steps.length - 1,
                    value: index.toDouble(),
                    label: size,
                    semanticFormatterCallback: (value) =>
                        formatMediaCacheSize(steps[value.round()]),
                    onChanged: (value) =>
                        setState(() => _draggingMb = steps[value.round()]),
                    onChangeEnd: (value) {
                      setState(() => _draggingMb = null);
                      widget.onChanged(steps[value.round()]);
                    },
                  ),
                ),
                if (widget.trailing case final trailing?)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: trailing,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
