import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The ids a merge address carries (`state.extra`), or none.
List<String> buddyMergeIds(Object? extra) => extra is List
    ? [for (final id in extra) ?(id is String ? id : null)]
    : const [];

/// The merge address's redirect (issue #4527, phase 3): back to the buddy
/// list when it does not carry two or more buddies to merge, as the site
/// merge does.
String? buddyMergeRedirect(BuildContext context, GoRouterState state) =>
    buddyMergeIds(state.extra).length < 2 ? '/buddies' : null;
