import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

/// A browser engine is never a pop-out window.
Future<PopOutLaunch?> readPopOutLaunch() async => null;

/// Never called in a browser: [readPopOutLaunch] finds no launch.
Future<void> runPopOutApp(PopOutLaunch launch) async {
  throw UnsupportedError('Browsers have no pop-out windows');
}
