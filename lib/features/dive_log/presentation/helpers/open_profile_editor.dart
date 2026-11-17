import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/computer_source_sheet.dart';

/// What the profile editor did: whether it saved, and whether the dive's
/// primary source changed while it was open.
typedef ProfileEditorResult = ({bool saved, bool promoted});

/// Opens the profile editor for [diveId], which saves on its own page.
///
/// It first asks which source's profile to start from when more than one
/// source has samples of its own (issue #3066). [initialMode] `'draw'` draws
/// a profile for a dive that has none, and asks nothing. Used by the dive
/// edit form and by the Profile card (issue #4527).
Future<ProfileEditorResult> openProfileEditor(
  BuildContext context,
  WidgetRef ref,
  String diveId, {
  String? initialMode,
}) async {
  const nothing = (saved: false, promoted: false);
  if (initialMode == 'draw') {
    final saved = await context.pushNamed<bool>(
      'editProfile',
      pathParameters: {'diveId': diveId},
      queryParameters: {'mode': 'draw'},
    );
    return (saved: saved == true, promoted: false);
  }
  final sources = await ref.read(diveDataSourcesProvider(diveId).future);
  // Most dives have one source and can never offer a choice, so only a
  // multi-source dive pays for hydrating every source's samples.
  final startable = sources.length < 2
      ? sources
      : startableProfileSources(
          sources,
          await ref.read(sourceProfilesProvider(diveId).future),
        );
  if (!context.mounted) return nothing;

  // A single source needs no naming: the dive's profile is its own. With
  // more, name the source even when it is the primary, since the dive's
  // profile interleaves every source. Saving an edit of another source
  // makes it primary.
  DiveDataSource? chosen;
  if (startable.length > 1) {
    chosen = await showModalBottomSheet<DiveDataSource>(
      context: context,
      builder: (context) => ComputerSourceSelectionSheet(readings: startable),
    );
    if (chosen == null || !context.mounted) return nothing;
  } else if (sources.length > 1 && startable.length == 1) {
    // Only one source has samples, and it may not be the primary: the
    // edit is that source's, not the sample-less primary's.
    chosen = startable.single;
  }
  final sourceId = chosen?.id;
  final primaryBefore = sources.where((s) => s.isPrimary).firstOrNull?.id;
  final repository = ref.read(diveRepositoryProvider);

  final saved = await context.pushNamed<bool>(
    'editProfile',
    pathParameters: {'diveId': diveId},
    queryParameters: {'mode': ?initialMode, 'sourceId': ?sourceId},
  );
  if (saved != true) return nothing;
  // Saving an edit of another source promotes it, and so can switching or
  // deleting a revision in the editor, so ask which source is primary now
  // rather than inferring it from the source chosen here.
  final sourcesAfter = await repository.getDataSources(diveId);
  final primaryAfter = sourcesAfter.where((s) => s.isPrimary).firstOrNull?.id;
  return (saved: true, promoted: primaryAfter != primaryBefore);
}
