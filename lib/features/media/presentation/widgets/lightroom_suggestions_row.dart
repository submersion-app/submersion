import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Ambiguous Lightroom matches for a dive: a horizontal row of suggestion
/// cards with per-card accept and dismiss. Renders nothing when there are
/// no live connector suggestions or no connected account.
class LightroomSuggestionsRow extends ConsumerWidget {
  const LightroomSuggestionsRow({required this.diveId, super.key});

  final String diveId;

  Future<void> _accept(
    WidgetRef ref,
    domain.PendingPhotoSuggestion suggestion,
  ) async {
    final account = await ref.read(lightroomAccountProvider.future);
    if (account == null) return;
    await ref
        .read(lightroomScanServiceProvider)
        .confirmSuggestion(account: account, suggestion: suggestion);
    ref.invalidate(pendingSuggestionsForDiveProvider(diveId));
    ref.invalidate(mediaForDiveProvider(diveId));
  }

  Future<void> _dismiss(
    WidgetRef ref,
    domain.PendingPhotoSuggestion suggestion,
  ) async {
    await ref
        .read(mediaRepositoryProvider)
        .dismissPendingSuggestion(suggestion.id);
    ref.invalidate(pendingSuggestionsForDiveProvider(diveId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .value keeps showing the previous list during reloads instead of
    // flashing empty (AsyncValue reload-flicker trap).
    final suggestions =
        ref
            .watch(pendingSuggestionsForDiveProvider(diveId))
            .value
            ?.where((s) => s.remoteAssetId != null)
            .toList() ??
        const <domain.PendingPhotoSuggestion>[];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.l10n.media_lightroom_suggestions_title,
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _SuggestionCard(
                suggestion: suggestion,
                onAccept: () => _accept(ref, suggestion),
                onDismiss: () => _dismiss(ref, suggestion),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  final domain.PendingPhotoSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  Future<Uint8List?> _thumbnail(WidgetRef ref) async {
    final account = await ref.read(lightroomAccountProvider.future);
    final catalogId = account?.accountIdentifier;
    final assetId = suggestion.remoteAssetId;
    if (catalogId == null || assetId == null) return null;
    try {
      return await ref
          .read(lightroomApiClientProvider)
          .getRendition(
            catalogId: catalogId,
            assetId: assetId,
            size: 'thumbnail2x',
          );
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List?>(
                future: _thumbnail(ref),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.photo_outlined)),
                    );
                  }
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  );
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.check, color: colorScheme.primary),
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.media_lightroom_suggestion_accept,
                onPressed: onAccept,
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.outline),
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.media_lightroom_suggestion_dismiss,
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
