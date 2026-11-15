import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// What a [RecordEditController] asks to be shown: a card, or with a field
/// one row of it.
typedef RevealRequest = ({String cardId, String? fieldId, int serial});

/// Answers a controller's request to be scrolled into view, once.
///
/// A card's frame and a field's row both answer such requests, each for its
/// own. Call [answerReveal] from `didChangeDependencies`, which runs as the
/// widget mounts and each time the controller notifies.
mixin RevealAnswering<W extends StatefulWidget> on State<W> {
  /// The last request answered here, so one request scrolls once however
  /// often the page rebuilds before it is withdrawn.
  int _answeredSerial = 0;

  /// Scrolls this widget into view when [controller] holds a request that
  /// [isMine] and that has not been answered here, and withdraws the
  /// request. [alignment] is where in the viewport the widget comes to rest.
  void answerReveal<T>(
    RecordEditController<T>? controller, {
    required bool Function(RevealRequest request) isMine,
    required double alignment,
  }) {
    final request = controller?.revealRequest;
    if (controller == null || request == null) return;
    if (!isMine(request) || request.serial == _answeredSerial) return;
    _answeredSerial = request.serial;
    // After this frame, when the widget has its place and its size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.revealHandled(request.serial);
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: alignment,
        duration: const Duration(milliseconds: 200),
      );
    });
  }
}
