import 'dart:convert';
import 'dart:typed_data';

/// What the initiator wants from a session.
enum NearbyIntent { sync, pair }

/// Why a session was refused. The [index] travels as the single byte of an
/// `error` frame, so values are only ever appended.
enum NearbyErrorCode {
  /// The refusing side needs a newer app to talk to this peer.
  newerApp,

  /// The refusing side's peer is too old for it.
  olderApp,
  differentLibrary,
  notPaired,
  protocol,
  busy;

  static NearbyErrorCode fromByte(int byte) =>
      byte < values.length ? values[byte] : protocol;
}

/// What this device says about itself in its hello.
class NearbyIdentity {
  const NearbyIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
    required this.schemaVersion,
    required this.epochId,
    required this.hasDives,
  });

  final String deviceId;
  final String deviceName;
  final String appVersion;
  final int schemaVersion;

  /// The library epoch this device has accepted, or null when it has never
  /// joined a library (no backend and never paired).
  final String? epochId;
  final bool hasDives;

  NearbyIdentity copyWith({String? epochId}) => NearbyIdentity(
    deviceId: deviceId,
    deviceName: deviceName,
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    epochId: epochId ?? this.epochId,
    hasDives: hasDives,
  );
}

/// The first, plaintext message each way.
///
/// The initiator's hello carries a [commitment] (a hash of its public key)
/// and no key; the responder's carries its [publicKey]. The initiator then
/// reveals its key in a `helloReveal` frame.
class NearbyHello {
  const NearbyHello({
    required this.protocolVersion,
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
    required this.schemaVersion,
    required this.epochId,
    required this.hasDives,
    required this.intent,
    this.publicKey,
    this.commitment,
  });

  factory NearbyHello.from(
    NearbyIdentity identity, {
    required NearbyIntent intent,
    Uint8List? publicKey,
    Uint8List? commitment,
  }) => NearbyHello(
    protocolVersion: currentProtocolVersion,
    deviceId: identity.deviceId,
    deviceName: identity.deviceName,
    appVersion: identity.appVersion,
    schemaVersion: identity.schemaVersion,
    epochId: identity.epochId,
    hasDives: identity.hasDives,
    intent: intent,
    publicKey: publicKey,
    commitment: commitment,
  );

  static const currentProtocolVersion = 1;

  final int protocolVersion;
  final String deviceId;
  final String deviceName;
  final String appVersion;
  final int schemaVersion;
  final String? epochId;
  final bool hasDives;
  final NearbyIntent intent;
  final Uint8List? publicKey;
  final Uint8List? commitment;

  Map<String, Object?> toJson() => {
    'v': protocolVersion,
    'id': deviceId,
    'name': deviceName,
    'app': appVersion,
    'schema': schemaVersion,
    'epoch': epochId,
    'dives': hasDives,
    'intent': intent.name,
    if (publicKey != null) 'pub': base64Encode(publicKey!),
    if (commitment != null) 'commit': base64Encode(commitment!),
  };

  /// Throws [FormatException] on anything that is not a well-formed hello.
  factory NearbyHello.fromJson(Map<String, Object?> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is T) return value;
      throw FormatException('hello field $key is missing or malformed');
    }

    Uint8List? bytes(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw FormatException('hello field $key');
      return base64Decode(value);
    }

    final intentName = field<String>('intent');
    final intent = NearbyIntent.values.where((i) => i.name == intentName);
    if (intent.isEmpty) throw FormatException('unknown intent $intentName');
    return NearbyHello(
      protocolVersion: field<int>('v'),
      deviceId: field<String>('id'),
      deviceName: field<String>('name'),
      appVersion: field<String>('app'),
      schemaVersion: field<int>('schema'),
      epochId: json['epoch'] as String?,
      hasDives: field<bool>('dives'),
      intent: intent.single,
      publicKey: bytes('pub'),
      commitment: bytes('commit'),
    );
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory NearbyHello.fromBytes(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('hello is not an object');
    }
    return NearbyHello.fromJson(decoded);
  }
}
