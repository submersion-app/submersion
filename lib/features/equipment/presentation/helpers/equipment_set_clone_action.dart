import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/section_navigation.dart';

/// The set page's Clone (issue #2156): opens the set form filled in from
/// [setId]. Nothing is written until the diver saves there; once they do,
/// the clone is shown in place of [setId], as the equipment clone opens the
/// clone. A discarded clone leaves the page as it was.
///
/// In the desktop split the set page is the detail pane of the sets list,
/// which follows `?setSelected=`, so the clone is selected in the list. On
/// a phone the clone's page replaces the source's, and Back still returns
/// to the list.
Future<void> cloneEquipmentSet(BuildContext context, String setId) async {
  final cloneId = await context.push<String>(
    '/equipment/sets/new?cloneFrom=$setId',
  );
  if (cloneId == null || !context.mounted) return;
  final uri = GoRouterState.of(context).uri;
  if (uri.queryParameters.containsKey('setSelected')) {
    context.goInPlace(
      uri
          .replace(
            queryParameters: {...uri.queryParameters, 'setSelected': cloneId},
          )
          .toString(),
    );
  } else {
    context.pushReplacement('/equipment/sets/$cloneId');
  }
}
