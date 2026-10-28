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
    required this.schemaFloor,
    required this.epochId,
    required this.hasDives,
  });

  final String deviceId;
  final String deviceName;
  final String appVersion;

  /// The schema this build writes.
  final int schemaVersion;

  /// The oldest schema that can read this build's rows (the sync
  /// compatibility floor). A receiver whose [schemaVersion] is below the
  /// sender's floor cannot apply what it would send.
  final int schemaFloor;

  /// The library epoch this device has accepted, or null when it has never
  /// joined a library (no backend and never paired).
  final String? epochId;
  final bool hasDives;

  NearbyIdentity copyWith({String? epochId}) => NearbyIdentity(
    deviceId: deviceId,
    deviceName: deviceName,
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    schemaFloor: schemaFloor,
    epochId: epochId ?? this.epochId,
    hasDives: hasDives,
  );

  Map<String, Object?> toJson() => {
    'id': deviceId,
    'name': deviceName,
    'app': appVersion,
    'schema': schemaVersion,
    'floor': schemaFloor,
    'epoch': epochId,
    'dives': hasDives,
  };

  /// Throws [FormatException] on anything that is not a well-formed
  /// identity.
  factory NearbyIdentity.fromJson(Map<String, Object?> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is T) return value;
      throw FormatException('identity field $key is missing or malformed');
    }

    final epoch = json['epoch'];
    if (epoch != null && epoch is! String) {
      throw const FormatException('identity field epoch');
    }
    return NearbyIdentity(
      deviceId: field<String>('id'),
      deviceName: field<String>('name'),
      appVersion: field<String>('app'),
      schemaVersion: field<int>('schema'),
      schemaFloor: field<int>('floor'),
      epochId: epoch as String?,
      hasDives: field<bool>('dives'),
    );
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory NearbyIdentity.fromBytes(Uint8List bytes) =>
      NearbyIdentity.fromJson(_object(bytes, 'identity'));
}

Map<String, Object?> _object(Uint8List bytes, String what) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$what is not an object');
  }
  return decoded;
}

/// The first, plaintext message each way. It names neither device: anyone
/// in range can read it, so it carries only the protocol version, the
/// intent and key material (the spec's anti-goal: a stranger learns at
/// most that this is a Submersion device). Who each side is travels sealed
/// after the key check, as a [NearbyIdentity].
///
/// The initiator commits to its key ([commitment]) and reveals it in a
/// `helloReveal` frame after the responder's hello carries [publicKey].
/// For a sync, the initiator sends one anonymous [tags] entry per device it
/// is paired with, and the responder answers with the one [tag] for the
/// pairing it recognised. Tags are keyed by the pair secret over this
/// session's fresh commitment, so they say nothing to anyone without the
/// secret and differ every session.
class NearbyHello {
  const NearbyHello({
    required this.protocolVersion,
    required this.intent,
    this.publicKey,
    this.commitment,
    this.tags = const [],
    this.tag,
  });

  static const currentProtocolVersion = 1;

  final int protocolVersion;
  final NearbyIntent intent;
  final Uint8List? publicKey;
  final Uint8List? commitment;
  final List<Uint8List> tags;
  final Uint8List? tag;

  Map<String, Object?> toJson() => {
    'v': protocolVersion,
    'intent': intent.name,
    if (publicKey != null) 'pub': base64Encode(publicKey!),
    if (commitment != null) 'commit': base64Encode(commitment!),
    if (tags.isNotEmpty) 'tags': [for (final t in tags) base64Encode(t)],
    if (tag != null) 'tag': base64Encode(tag!),
  };

  /// Throws [FormatException] on anything that is not a well-formed hello.
  factory NearbyHello.fromJson(Map<String, Object?> json) {
    final v = json['v'];
    if (v is! int) throw const FormatException('hello field v');
    final intentName = json['intent'];
    final intent = NearbyIntent.values.where((i) => i.name == intentName);
    if (intent.isEmpty) throw FormatException('unknown intent $intentName');

    Uint8List? bytes(Object? value) {
      if (value == null) return null;
      if (value is! String) throw const FormatException('hello bytes');
      return base64Decode(value);
    }

    final rawTags = json['tags'];
    if (rawTags != null && rawTags is! List) {
      throw const FormatException('hello field tags');
    }
    for (final t in (rawTags as List?) ?? const []) {
      if (t is! String) throw const FormatException('hello tag');
    }
    return NearbyHello(
      protocolVersion: v,
      intent: intent.single,
      publicKey: bytes(json['pub']),
      commitment: bytes(json['commit']),
      tags: [for (final t in rawTags ?? const []) bytes(t)!],
      tag: bytes(json['tag']),
    );
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory NearbyHello.fromBytes(Uint8List bytes) =>
      NearbyHello.fromJson(_object(bytes, 'hello'));

  /// The protocol version a hello announces, read on its own so a newer
  /// hello this build cannot parse still says what it is; null when
  /// [bytes] are not a hello object with an integer version.
  static int? versionOf(Uint8List bytes) {
    try {
      final v = _object(bytes, 'hello')['v'];
      return v is int ? v : null;
    } on Object {
      return null;
    }
  }
}
