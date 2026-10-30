import 'dart:typed_data';

/// Whether this device's radio can be used for the nearby link right now.
enum NearbyAvailability { ready, bluetoothOff, unauthorized, unsupported }

/// A nearby Submersion device seen advertising. [transportId] is the
/// carrier's address for it (a Bluetooth address or UUID); it says nothing
/// about who the device is, which only the hello reveals.
class NearbyPeerSighting {
  const NearbyPeerSighting({required this.transportId, required this.seenAt});

  final String transportId;
  final DateTime seenAt;
}

/// The link could not be opened.
class NearbyConnectFailed implements Exception {
  const NearbyConnectFailed(this.message);

  final String message;

  @override
  String toString() => 'NearbyConnectFailed: $message';
}

/// A send on an endpoint that has already closed.
class NearbyLinkClosed implements Exception {
  const NearbyLinkClosed();

  @override
  String toString() => 'NearbyLinkClosed';
}

/// One open link between two devices: an ordered, reliable byte stream each
/// way. Chunk boundaries carry no meaning; the frame decoder reassembles.
abstract class NearbyEndpoint {
  /// Bytes from the other device. Closes when the link drops.
  Stream<Uint8List> get inbound;

  /// Sends [bytes] in order after anything sent before. Throws
  /// [NearbyLinkClosed] once the link is gone.
  Future<void> send(Uint8List bytes);

  Future<void> close();

  /// True on the side that connected (the scanner).
  bool get isInitiator;

  /// The carrier address of the other device.
  String get transportId;
}

/// Moves bytes between nearby devices: advertise to be found, scan to find,
/// connect to open an [NearbyEndpoint].
abstract class NearbyCarrier {
  /// False where the platform cannot host the Submersion service (Linux).
  bool get canAdvertise;

  Future<void> startAdvertising();

  Future<void> stopAdvertising();

  Future<void> startScanning();

  Future<void> stopScanning();

  Stream<NearbyPeerSighting> get sightings;

  /// Links opened by devices that found this one advertising.
  Stream<NearbyEndpoint> get incoming;

  Future<NearbyEndpoint> connect(String transportId);

  /// Changes to [checkAvailability].
  Stream<NearbyAvailability> get availability;

  /// The radio's state now, asking for Bluetooth permission first where the
  /// platform needs it at runtime (Android 12+, Apple).
  Future<NearbyAvailability> checkAvailability();
}
