// Manifest mode panel inside the URL tab (Phase 3b, Task 13).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 13. The panel renders one of four bodies based on the
// [ManifestTabState] discriminated union:
//
// - [ManifestTabIdle]            -> hint text "Paste a manifest URL to begin."
// - [ManifestTabFetching]        -> CircularProgressIndicator
// - [ManifestTabError]           -> red error message
// - [ManifestTabShowingPreview]  -> [ManifestPreviewPane] + Subscribe
//                                   checkbox + poll-interval dropdown
//
// Task 13 is UI-only — the Subscribe checkbox and poll-interval dropdown
// flip state on the notifier but the actual subscription persistence /
// import-commit flow is wired in Task 14. The "Import" button is also
// added in Task 14.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_preview_pane.dart';

/// Standard poll-interval choices surfaced in the dropdown. The plan's
/// 24-hour default sits at the middle of the list.
const List<_PollIntervalOption> _kPollIntervals = [
  _PollIntervalOption(seconds: 3600, label: '1 hour'),
  _PollIntervalOption(seconds: 21600, label: '6 hours'),
  _PollIntervalOption(seconds: 86400, label: '24 hours'),
  _PollIntervalOption(seconds: 604800, label: '7 days'),
];

class ManifestModePanel extends ConsumerStatefulWidget {
  const ManifestModePanel({super.key});

  @override
  ConsumerState<ManifestModePanel> createState() => _ManifestModePanelState();
}

class _ManifestModePanelState extends ConsumerState<ManifestModePanel> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final notifier = ref.read(manifestTabProvider.notifier);
    await notifier.fetch(_urlController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manifestTabProvider);
    final isFetching = state is ManifestTabFetching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isFetching ? null : _fetch(),
          decoration: const InputDecoration(
            // TODO(media): l10n
            labelText: 'Manifest URL',
            // TODO(media): l10n
            hintText: 'https://example.com/manifest.json',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.cloud_download),
            // TODO(media): l10n
            label: const Text('Fetch'),
            onPressed: isFetching ? null : _fetch,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _Body(state: state)),
      ],
    );
  }
}

/// State-driven body of the panel — separated out so the `switch` over the
/// sealed [ManifestTabState] reads top-to-bottom in one place.
class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final ManifestTabState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    switch (state) {
      case ManifestTabIdle():
        // TODO(media): l10n
        return const Align(
          alignment: Alignment.topLeft,
          child: Text('Paste a manifest URL to begin.'),
        );
      case ManifestTabFetching():
        return const Center(child: CircularProgressIndicator());
      case ManifestTabError(:final message):
        return Align(
          alignment: Alignment.topLeft,
          // TODO(media): l10n
          child: Text(
            'Fetch failed: $message',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        );
      case ManifestTabShowingPreview(
        :final result,
        :final formatOverride,
        :final subscribe,
        :final pollIntervalSeconds,
      ):
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ManifestPreviewPane(
                result: result,
                formatOverride: formatOverride,
                onFormatOverrideChanged: (format) {
                  ref
                      .read(manifestTabProvider.notifier)
                      .changeFormatOverride(format);
                },
              ),
              const SizedBox(height: 16),
              _SubscribeRow(
                subscribe: subscribe,
                pollIntervalSeconds: pollIntervalSeconds,
                onSubscribeChanged: (value) {
                  ref.read(manifestTabProvider.notifier).setSubscribe(value);
                },
                onPollIntervalChanged: (seconds) {
                  ref
                      .read(manifestTabProvider.notifier)
                      .setPollInterval(seconds);
                },
              ),
            ],
          ),
        );
      case ManifestTabCommitting():
        return const Center(child: CircularProgressIndicator());
    }
  }
}

/// Subscribe checkbox + (conditionally rendered) poll-interval dropdown.
///
/// Task 13: these inputs are UI placeholders that toggle state on the
/// notifier; Task 14 wires actual subscription persistence on Import.
class _SubscribeRow extends StatelessWidget {
  const _SubscribeRow({
    required this.subscribe,
    required this.pollIntervalSeconds,
    required this.onSubscribeChanged,
    required this.onPollIntervalChanged,
  });

  final bool subscribe;
  final int pollIntervalSeconds;
  final ValueChanged<bool> onSubscribeChanged;
  final ValueChanged<int> onPollIntervalChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: subscribe,
              onChanged: (value) => onSubscribeChanged(value ?? false),
            ),
            // TODO(media): l10n
            const Expanded(child: Text('Subscribe to updates')),
          ],
        ),
        if (subscribe) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                // TODO(media): l10n
                Text(
                  'Poll every:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _resolvedSelection(pollIntervalSeconds),
                  onChanged: (value) {
                    if (value != null) onPollIntervalChanged(value);
                  },
                  items: _kPollIntervals
                      .map(
                        (option) => DropdownMenuItem<int>(
                          value: option.seconds,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Map the persisted seconds value to the closest dropdown option so
  /// arbitrary stored values still pick a sensible item. Defaults to
  /// the 24-hour middle option when nothing matches.
  int _resolvedSelection(int seconds) {
    for (final option in _kPollIntervals) {
      if (option.seconds == seconds) return option.seconds;
    }
    return 86400;
  }
}

class _PollIntervalOption {
  const _PollIntervalOption({required this.seconds, required this.label});

  final int seconds;
  final String label;
}
