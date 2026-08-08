import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_import_link_page.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Import console section (Media section Phase 4): launches the
/// existing three-tab picker with NO dive context, imports the selection
/// into the library (retained, unlinked), then hands the batch to
/// [MediaImportLinkPage] for one-tap auto-match linking.
class MediaImportView extends ConsumerWidget {
  const MediaImportView({super.key, this.launchOverride});

  /// Test seam: returns the imported media ids instead of driving the
  /// platform picker (which flutter_test cannot).
  @visibleForTesting
  final Future<List<String>> Function(BuildContext context)? launchOverride;

  /// Lower bound of the gallery tab's date window for a dive-less import.
  ///
  /// The mobile picker turns this into a hard photo_manager
  /// `DateTimeCond(min:)`, so a "recent enough" sentinel would quietly hide
  /// everything older -- scanned film and slide libraries being exactly the
  /// media a diver back-fills. Epoch is photo_manager's own no-lower-bound
  /// value (`DateTimeCond.def()`), so it reads as unbounded to the native
  /// query rather than as an arbitrary cutoff.
  static final DateTime libraryWindowStart =
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<String>> _pickAndImport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // No dive context: there is no meaningful date window, so the gallery
    // tab gets an unbounded one (desktop file dialogs ignore it entirely).
    final selected = await showPhotoPicker(
      context: context,
      diveStartTime: libraryWindowStart,
      diveEndTime: DateTime.now().add(const Duration(days: 1)),
      buffer: Duration.zero,
    );
    if (selected == null || selected.isEmpty) return const [];

    final result = await ref
        .read(mediaImportServiceProvider)
        .importPhotosToLibrary(selectedAssets: selected);
    return [for (final item in result.imported) item.id];
  }

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    final ids =
        await (launchOverride?.call(context) ?? _pickAndImport(context, ref));
    if (ids.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportLinkPage(mediaIds: ids),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.media_import_intro, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(context.l10n.media_import_launch),
              onPressed: () => _launch(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
