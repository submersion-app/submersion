import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_editing_page_provider.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';
import 'package:submersion/features/media/presentation/helpers/photo_import_helper.dart';
import 'package:submersion/features/media/presentation/helpers/site_media_import_helper.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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
///
/// A dive takes files only in its open sitting, held there until Save; a
/// drop on a locked dive, one being saved, or one the list pane shows is
/// refused with a hint (issue #4527). So does a site whose page edits in
/// place; on any other site's page the files are imported at once.
Future<void> importDroppedMedia(
  BuildContext context,
  WidgetRef ref,
  MediaDropDestination destination,
  List<String> paths,
) async {
  final target = destination.target;
  if (target is SiteAttachTarget) {
    final page = ref.read(siteEditingPageProvider);
    switch (siteDropAnswer(page: page, siteId: target.siteId)) {
      case SiteDropAnswer.importNow:
        return _importDropped(context, ref, destination, paths);
      case SiteDropAnswer.refuse:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.diveSites_media_dropUnlockHint)),
        );
      case SiteDropAnswer.hold:
        final session = page!.session!;
        page.showMediaCard();
        await _holdSiteDropped(context, ref, session, paths);
    }
    return;
  }
  if (target is! DiveAttachTarget) {
    return _importDropped(context, ref, destination, paths);
  }
  final open = ref.read(openDiveSittingProvider);
  switch (diveDropAnswer(open: open, diveId: target.diveId)) {
    case DiveDropAnswer.refuse:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diveLog_media_dropUnlockHint)),
      );
    case DiveDropAnswer.hold:
      final session = open!.session;
      open.showMediaCard();
      await _holdDropped(context, ref, session, paths);
  }
}

// coverage:ignore-start
// Every branch ends in showPhotoPicker, a full-screen page tied to
// photo_manager and the platform photo library, which flutter_test cannot
// drive. Choosing the destination is mediaDropDestinationFor's job, covered
// by media_drop_destination_test; handing it here is covered by
// global_drop_target_test, and the answer for a dive by
// open_dive_sitting_provider_test and media_drop_import_test.
Future<void> _holdDropped(
  BuildContext context,
  WidgetRef ref,
  EditSession<Dive> session,
  List<String> paths,
) async {
  await PhotoImportHelper.importPhotosForDive(
    context: context,
    ref: ref,
    dive: session.working,
    initialFilePaths: paths,
    onHold: (adds) => addMediaToSitting(session, adds),
  );
}

Future<void> _holdSiteDropped(
  BuildContext context,
  WidgetRef ref,
  EditSession<DiveSite> session,
  List<String> paths,
) async {
  await SiteMediaImportHelper.importPhotosForSite(
    context: context,
    ref: ref,
    siteId: session.stored.id,
    initialFilePaths: paths,
    onHold: (adds) => addMediaToSitting(session, adds),
    unlinkedInSitting: sittingMedia(session).unlinked,
  );
}

Future<void> _importDropped(
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
