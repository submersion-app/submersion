import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Whether the page holding [context] has a page under it to go back to.
///
/// Page-local on purpose: the router as a whole can pop whenever anything on
/// the stack can, which says nothing about this page.
bool isPushedRoute(BuildContext context) =>
    ModalRoute.of(context)?.canPop ?? false;

/// Whether a standalone detail page should move itself into its section's
/// master-detail split (`/<section>?selected=<id>`).
///
/// Only a root page does: a deep link or a sidebar visit. A page pushed from
/// somewhere else (a dive's linked gear, a buddy's shared dive) stays put, or
/// the redirect's `go` would erase the page it came from and its back arrow
/// with it (#764, #3292). Embedded pages, phone widths and table mode (which
/// has no split to move into) never redirect.
bool shouldRedirectToMasterDetail(
  BuildContext context, {
  required bool embedded,
  required ListViewMode viewMode,
}) =>
    !embedded &&
    !isPushedRoute(context) &&
    ResponsiveBreakpoints.isMasterDetail(context) &&
    viewMode != ListViewMode.table;
