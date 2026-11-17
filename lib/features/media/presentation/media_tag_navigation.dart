import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

/// Opens the media library showing only what [filter] selects.
///
/// Called from sheets and chips over the viewer, which is pushed
/// imperatively above the router's page: going to `/media` from `/media`
/// would leave both on screen. So every pageless route above the router's
/// page (the sheet, the viewer) is popped first. The router is read before,
/// because [context] and [ref] belong to the sheet.
///
/// The filter is replaced rather than merged: a leftover site, trip or date
/// bound would hide some of what was asked for. The library's active filter
/// chips clear it again.
///
/// A route that refuses to be popped (the viewer unlocked with unsaved
/// changes, issue #4527) is not popped past: `Navigator.pop` would close it
/// anyway and its guard would drop the changes unasked. It is asked
/// instead, as Back asks it, and the library is not opened.
void openMediaWithFilter(
  BuildContext context,
  WidgetRef ref,
  MediaLibraryFilter filter,
) {
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context);
  var guarded = false;
  navigator.popUntil((route) {
    if (route.settings is Page) return true;
    if (route.popDisposition == RoutePopDisposition.doNotPop) {
      guarded = true;
      return true;
    }
    return false;
  });
  if (guarded) {
    unawaited(navigator.maybePop());
    return;
  }
  ref.read(mediaLibraryFilterProvider.notifier).state = filter;
  router.go('/media');
}

/// Opens the media library showing only the photos and videos tagged
/// [tagId] (issue #1970), the media twin of `openEquipmentWithTag`.
void openMediaWithTag(BuildContext context, WidgetRef ref, String tagId) =>
    openMediaWithFilter(context, ref, MediaLibraryFilter(tagIds: {tagId}));

/// Opens the media library showing only the photos and videos the active
/// diver is tagged in as "Me" (issue #1745), from the Me chip over the
/// viewer.
void openMediaWithMe(BuildContext context, WidgetRef ref) =>
    openMediaWithFilter(
      context,
      ref,
      const MediaLibraryFilter(includeMe: true),
    );

/// Opens the media library showing only the photos and videos [buddyId] is
/// tagged in (issue #1745), from the buddy page's photo card.
void openMediaWithBuddy(BuildContext context, WidgetRef ref, String buddyId) =>
    openMediaWithFilter(context, ref, MediaLibraryFilter(buddyIds: {buddyId}));
