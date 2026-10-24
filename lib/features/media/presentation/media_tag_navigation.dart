import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

/// Opens the media library showing only the photos and videos tagged
/// [tagId] (issue #1970), the media twin of `openEquipmentWithTag`.
///
/// Called from the info sheet over the viewer, which is pushed imperatively
/// above the router's page: going to `/media` from `/media` would leave both
/// on screen. So every pageless route above the router's page (the sheet,
/// the viewer) is popped first. The router is read before, because
/// [context] and [ref] belong to the sheet.
///
/// The filter is replaced rather than merged: a leftover site, trip or date
/// bound would hide some of the tag's media. The active filter chip on the
/// library clears the tag again.
void openMediaWithTag(BuildContext context, WidgetRef ref, String tagId) {
  final router = GoRouter.of(context);
  ref.read(mediaLibraryFilterProvider.notifier).state = MediaLibraryFilter(
    tagIds: {tagId},
  );
  Navigator.of(context).popUntil((route) => route.settings is Page);
  router.go('/media');
}
