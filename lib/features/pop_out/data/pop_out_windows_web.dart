import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

/// A browser has one window: nothing opens, nothing is ever a pop-out.
PopOutWindows createPopOutWindows() => _NoPopOutWindows();

class _NoPopOutWindows implements PopOutWindows {
  @override
  final PopOutChannel channel = _NoChannel();

  @override
  Future<void> openProfile(PopOutLaunch launch) async {}

  @override
  Future<bool> isOpen() async => false;

  @override
  Future<PopOutLaunch?> currentLaunch() async => null;
}

class _NoChannel implements PopOutChannel {
  @override
  Future<void> send(PopOutMessage message) async {}

  @override
  void setHandler(void Function(PopOutMessage message)? handler) {}
}
