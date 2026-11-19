import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Pushes a satellite page of a record of type [T] (issue #4527, phase 3):
/// a page of the same record holding some of its cards, such as a gear
/// item's passport or a trip's cylinder board.
///
/// When the record's page has a sitting open, [builder] is handed its
/// controller, and the satellite joins that sitting (its
/// `RecordEditHost.joinedSitting`): its changes are the record page's to
/// save or cancel. Otherwise it is handed null and the satellite has a lock
/// of its own. [context] is one below the record page's [RecordEditScope].
Future<R?> pushRecordSatellite<T, R>(
  BuildContext context, {
  required Widget Function(RecordEditController<T>? joined) builder,
  bool rootNavigator = true,
}) {
  // Read once, not listened to: this runs from a tap.
  final controller = context
      .getInheritedWidgetOfExactType<RecordEditScope<T>>()
      ?.notifier;
  final joined = controller != null && controller.isUnlocked
      ? controller
      : null;
  return Navigator.of(
    context,
    rootNavigator: rootNavigator,
  ).push<R>(MaterialPageRoute<R>(builder: (_) => builder(joined)));
}
