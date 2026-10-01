import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';
import 'package:submersion/features/media/presentation/helpers/photo_import_helper.dart';
import 'package:submersion/features/media/presentation/helpers/site_media_import_helper.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';

/// Imports photos and videos dropped onto the app window.
typedef MediaDropHandler =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      MediaDropDestination destination,
      List<String> paths,
    );

/// Opens the importer [destination] names, with the dropped [paths] staged
/// in the picker's Files tab for review: the same importer the dive, site or
/// Media section's own "add" action opens, so a drop links files exactly the
/// way picking them does (issue #2488).
///
/// A dive deleted between the drop and this lookup falls back to the Media
/// section's importer, which matches the files to dives by capture time.
// coverage:ignore-start
// Every branch ends in showPhotoPicker, a full-screen page tied to
// photo_manager and the platform photo library, which flutter_test cannot
// drive. Choosing the destination is mediaDropDestinationFor's job, covered
// by media_drop_destination_test; handing it here is covered by
// global_drop_target_test.
Future<void> importDroppedMedia(
  BuildContext context,
  WidgetRef ref,
  MediaDropDestination destination,
  List<String> paths,
) async {
  final target = destination.target;
  if (target is SiteAttachTarget) {
    await SiteMediaImportHelper.importPhotosForSite(
      context: context,
      ref: ref,
      siteId: target.siteId,
      initialFilePaths: paths,
    );
    return;
  }
  if (target is DiveAttachTarget) {
    final dive = await ref
        .read(diveRepositoryProvider)
        .getDiveById(target.diveId);
    if (!context.mounted) return;
    if (dive != null) {
      await PhotoImportHelper.importPhotosForDive(
        context: context,
        ref: ref,
        dive: dive,
        initialFilePaths: paths,
      );
      return;
    }
  }
  await MediaImportView.launchImport(context, ref, initialFilePaths: paths);
}

// coverage:ignore-end
