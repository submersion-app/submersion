import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Makes a record page's sitting work the app asks about before it is left
/// by a way the page cannot stop itself (issue #4527): another tab, a row
/// of the list pane, a quit. Back is the page's own leave guard.
///
/// While [controller] is unlocked it holds one [AppExitBlocker] on [guard]:
/// unsaved changes are work to lose, and [confirm] asks about them (it
/// answers true once the record is locked). A sitting with nothing to save
/// is no work: it ends with the page.
class RecordSittingExitBlocker<T> {
  RecordSittingExitBlocker({
    required RecordEditController<T> controller,
    required AppExitGuard guard,
    required Future<bool> Function() confirm,
    Object? Function()? page,
  }) : _controller = controller,
       _guard = guard {
    _blocker = AppExitBlocker(
      hasUnsavedWork: () => controller.isDirty,
      confirmLeaving: confirm,
      page: page,
    );
    controller.addListener(_follow);
    _follow();
  }

  final RecordEditController<T> _controller;
  final AppExitGuard _guard;
  late final AppExitBlocker _blocker;
  bool _holding = false;
  bool _disposed = false;

  void _follow() {
    if (_disposed) return;
    final unlocked = _controller.isUnlocked;
    if (unlocked == _holding) return;
    _holding = unlocked;
    unlocked ? _guard.hold(_blocker) : _guard.release(_blocker);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_follow);
    if (_holding) _guard.release(_blocker);
    _holding = false;
  }
}

/// [GoRoute.onExit] for a record page's routes: a `go` that would leave a
/// sitting with unsaved changes asks first. A Back that has already asked
/// finds nothing left to ask about.
///
/// Only the sittings on the page being left are asked about, matched by
/// [GoRouterState.pageKey], the key go_router builds that page with: a page
/// pushed above the list pane is popped without a word about the pane.
Future<bool> confirmLeaveRecordSitting(
  BuildContext context,
  GoRouterState state,
) => ProviderScope.containerOf(
  context,
  listen: false,
).read(appExitGuardProvider).mayLeave(page: state.pageKey);

/// The key of the page [context] is built in, as [GoRouterState.pageKey]
/// names it, for [RecordSittingExitBlocker]'s `page`. A satellite page,
/// pushed on a route of its own, is on the page of its record
/// ([RecordSatelliteRouteSettings]).
Object? recordSittingPageOf(BuildContext context) =>
    switch (ModalRoute.of(context)?.settings) {
      final Page<Object?> page => page.key,
      RecordSatelliteRouteSettings(:final recordPage) => recordPage,
      _ => null,
    };

/// The settings of a satellite page's route (`pushRecordSatellite`): the
/// key of the record page it was pushed from, so a sitting the satellite
/// holds is asked about when that page is left.
class RecordSatelliteRouteSettings extends RouteSettings {
  const RecordSatelliteRouteSettings({required this.recordPage});

  /// The record page's key, as [recordSittingPageOf] read it; null when
  /// that page is not a [Page] either.
  final Object? recordPage;
}
