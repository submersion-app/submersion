import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

/// A [PopOutChannel] that records what is sent and lets a test deliver what
/// the other window would send.
class FakePopOutChannel implements PopOutChannel {
  final sent = <PopOutMessage>[];
  void Function(PopOutMessage message)? _handler;

  bool get hasHandler => _handler != null;

  @override
  Future<void> send(PopOutMessage message) async => sent.add(message);

  @override
  void setHandler(void Function(PopOutMessage message)? handler) =>
      _handler = handler;

  /// Delivers [message] as if the other window had sent it.
  void deliver(PopOutMessage message) => _handler?.call(message);

  /// The messages of type [T] sent so far.
  List<T> sentOf<T extends PopOutMessage>() => sent.whereType<T>().toList();
}

/// [PopOutWindows] without real windows.
class FakePopOutWindows implements PopOutWindows {
  FakePopOutWindows({this.launch});

  /// What [currentLaunch] answers: the launch this engine was started with.
  final PopOutLaunch? launch;

  /// The one fake channel, whatever name is asked for.
  final FakePopOutChannel channel = FakePopOutChannel();

  /// Every channel name asked for, in order.
  final channelNames = <String>[];

  @override
  PopOutChannel channelNamed(String name) {
    channelNames.add(name);
    return channel;
  }

  /// Every launch [openProfile] was given.
  final opened = <PopOutLaunch>[];

  bool open = false;

  /// Makes the next [openProfile] throw, as a failed window creation does.
  bool failNextOpen = false;

  @override
  Future<void> openProfile(PopOutLaunch launch) async {
    if (failNextOpen) {
      failNextOpen = false;
      throw StateError('window creation failed');
    }
    opened.add(launch);
    open = true;
  }

  @override
  Future<bool> isOpen() async => open;

  @override
  Future<PopOutLaunch?> currentLaunch() async => launch;
}
