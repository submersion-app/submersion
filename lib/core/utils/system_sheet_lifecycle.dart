import 'package:flutter/widgets.dart';

/// What a lifecycle change means to the app root.
enum LifecycleMeaning {
  /// The diver may have left the app: start App Lock's clock.
  backgrounded,

  /// The diver came back: App Lock, sync and transfers get their turn.
  resumed,

  /// Nothing to act on.
  none,
}

/// Reads lifecycle changes, telling a system sheet over the app apart from
/// the diver leaving it.
///
/// A system sheet the app itself opened (the iOS NFC reader sheet) makes the
/// app inactive while it shows and resumed when it closes. Taken as leaving
/// and coming back, App Lock set to Immediately would lock after every tag
/// and every tag would start a sync. An inactive while such a sheet is up,
/// and the resumed that ends it, mean nothing; hidden or paused is still the
/// diver leaving, sheet or not.
class SystemSheetLifecycle {
  bool _inactiveForSheet = false;

  LifecycleMeaning interpret(
    AppLifecycleState state, {
    required bool systemSheetUp,
  }) {
    switch (state) {
      case AppLifecycleState.inactive:
        if (systemSheetUp) {
          _inactiveForSheet = true;
          return LifecycleMeaning.none;
        }
        return LifecycleMeaning.backgrounded;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _inactiveForSheet = false;
        return LifecycleMeaning.backgrounded;
      case AppLifecycleState.resumed:
        if (_inactiveForSheet) {
          _inactiveForSheet = false;
          return LifecycleMeaning.none;
        }
        return LifecycleMeaning.resumed;
      case AppLifecycleState.detached:
        return LifecycleMeaning.none;
    }
  }
}
