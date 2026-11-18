import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The dive page's gallery scan, for the open Media card (issue #4527): the
/// photos the gallery holds for the dive's time are found and confirmed as
/// today, then held in [session] until Save instead of linked at once.
Future<void> scanGalleryInSitting(
  BuildContext context,
  WidgetRef ref,
  EditSession<Dive> session,
) async {
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final dive = session.working;
  final mediaRepo = ref.read(mediaRepositoryProvider);
  final importService = ref.read(mediaImportServiceProvider);
  final linkedGalleryAssets = ref.read(linkedGalleryAssetsProvider);
  final photoPickerService = ref.read(photoPickerServiceProvider);
  final assets = await TripMediaScanner.scanGalleryForDive(
    dive: dive,
    linked: await mediaRepo.getGalleryLinksForDive(dive.id),
    linkedGalleryAssets: linkedGalleryAssets,
    photoPickerService: photoPickerService,
  );
  if (!context.mounted) return;
  if (assets == null || assets.isEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          assets == null
              ? l10n.media_diveScan_accessDenied
              : l10n.media_diveScan_noPhotosFound,
        ),
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.media_diveScan_foundTitle),
      content: Text(l10n.media_diveScan_foundPhotos(assets.length)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.media_diveScan_cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.media_diveScan_linkButton(assets.length)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final prepared = await importService.prepareForDive(
    selectedAssets: assets,
    dive: dive,
  );
  if (session.isDisposed || session.isFrozen) return;
  addMediaToSitting(session, [for (final p in prepared) HeldMediaRow(p)]);
}
