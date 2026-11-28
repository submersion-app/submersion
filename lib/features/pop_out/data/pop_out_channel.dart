import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

/// The line between the main window and its pop-out (issue #5078).
///
/// Each window holds one end. A message sent with nobody at the other end is
/// dropped, never an error: the pop-out may close at any moment.
abstract interface class PopOutChannel {
  Future<void> send(PopOutMessage message);

  /// Receives every message from the other window; null stops receiving.
  void setHandler(void Function(PopOutMessage message)? handler);
}
