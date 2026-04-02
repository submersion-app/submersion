import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/presentation/providers/csv_preset_providers.dart';

/// Bottom sheet that displays all available CSV presets (built-in + user-saved)
/// and lets the user select one to apply to the field mapping editor.
///
/// Returns the selected [CsvPreset] on tap, or null on dismiss.
class SelectPresetSheet extends ConsumerWidget {
  /// CSV headers from the current file, used to compute match scores.
  final List<String> csvHeaders;

  const SelectPresetSheet({super.key, required this.csvHeaders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userPresetsAsync = ref.watch(userCsvPresetsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Select Preset', style: theme.textTheme.titleLarge),
            ),
            const Divider(),
            Expanded(
              child: userPresetsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Failed to load presets: $e')),
                data: (userPresets) => _buildPresetList(
                  context,
                  ref,
                  userPresets,
                  scrollController,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresetList(
    BuildContext context,
    WidgetRef ref,
    List<CsvPreset> userPresets,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);

    // Score all presets directly without threshold filtering so the UI
    // shows partial match percentages even for low-scoring presets.
    final normalizedHeaders = csvHeaders
        .map((h) => h.toLowerCase().trim())
        .toSet();

    double scorePreset(CsvPreset preset) {
      if (preset.signatureHeaders.isEmpty) return 0.0;
      var matched = 0;
      for (final sig in preset.signatureHeaders) {
        if (normalizedHeaders.contains(sig.toLowerCase())) matched++;
      }
      return matched / preset.signatureHeaders.length;
    }

    final builtInScores = {
      for (final p in builtInCsvPresets) p: scorePreset(p),
    };
    final userScores = {for (final p in userPresets) p: scorePreset(p)};

    final hasUserPresets = userPresets.isNotEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (hasUserPresets) ...[
          _SectionHeader(label: 'Saved Presets', theme: theme),
          for (final preset in userPresets)
            _PresetCard(
              preset: preset,
              score: userScores[preset] ?? 0.0,

              onTap: () => Navigator.of(context).pop(preset),
              onDelete: () => _deletePreset(context, ref, preset),
            ),
          const SizedBox(height: 8),
        ],
        _SectionHeader(label: 'Built-in Presets', theme: theme),
        for (final preset in builtInCsvPresets)
          _PresetCard(
            preset: preset,
            score: builtInScores[preset] ?? 0.0,
            onTap: () => Navigator.of(context).pop(preset),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    CsvPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Delete "${preset.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(csvPresetRepositoryProvider);
    await repo.deletePreset(preset.id);
    ref.invalidate(userCsvPresetsProvider);
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 12, bottom: 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preset card
// ---------------------------------------------------------------------------

class _PresetCard extends StatelessWidget {
  final CsvPreset preset;
  final double score;

  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PresetCard({
    required this.preset,
    required this.score,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchedCount = (score * preset.signatureHeaders.length).round();
    final totalSig = preset.signatureHeaders.length;
    final scorePercent = (score * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            preset.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (preset.sourceApp != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              preset.sourceApp!.displayName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalSig > 0
                          ? '$matchedCount/$totalSig headers matched '
                                '($scorePercent%)'
                          : 'No signature headers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  onPressed: onDelete,
                  tooltip: 'Delete preset',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
