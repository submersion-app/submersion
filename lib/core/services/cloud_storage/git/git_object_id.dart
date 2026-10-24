import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The four Git object kinds, with their packfile type codes.
enum GitObjectType {
  commit(1),
  tree(2),
  blob(3),
  tag(4);

  const GitObjectType(this.packCode);

  /// The 3-bit type code a packfile entry header carries.
  final int packCode;

  /// The name in a loose object header (`blob 12\0...`).
  String get wireName => name;

  static GitObjectType fromPackCode(int code) {
    for (final type in values) {
      if (type.packCode == code) return type;
    }
    throw FormatException('Not a Git object type code: $code');
  }
}

/// A 20-byte SHA-1 object id. Immutable and compared by value.
final class GitObjectId {
  GitObjectId(Uint8List bytes) : _bytes = Uint8List.fromList(bytes) {
    if (bytes.length != 20) {
      throw FormatException('A Git object id is 20 bytes, got ${bytes.length}');
    }
  }

  factory GitObjectId.fromHex(String hex) {
    if (hex.length != 40) {
      throw FormatException('A Git object id is 40 hex digits: "$hex"');
    }
    // Checked first: int.parse would also take a sign ("+f" as 15).
    if (!_hexDigits.hasMatch(hex)) {
      throw FormatException('Not a hex Git object id: "$hex"');
    }
    final bytes = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return GitObjectId(bytes);
  }

  static final RegExp _hexDigits = RegExp(r'^[0-9a-fA-F]{40}$');

  /// All zeros: Git's "no object" (the old id when creating a ref).
  static final GitObjectId zero = GitObjectId(Uint8List(20));

  final Uint8List _bytes;

  /// A copy of the raw 20 bytes.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  String get hex {
    final buffer = StringBuffer();
    for (final b in _bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! GitObjectId) return false;
    for (var i = 0; i < 20; i++) {
      if (_bytes[i] != other._bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => hex;
}

/// The id Git gives an object of [type] whose content is [body]: the SHA-1 of
/// `'<type> <length>\0'` followed by the body.
GitObjectId hashGitObject(GitObjectType type, List<int> body) {
  // Header and body go to the hash in turn: joining them in one list would
  // copy the body, at about eight bytes per byte for a List<int>.
  final digest = DigestCollector();
  sha1.startChunkedConversion(digest)
    ..add(ascii.encode('${type.wireName} ${body.length}'))
    ..add(const [0])
    ..add(body)
    ..close();
  return GitObjectId(Uint8List.fromList(digest.value!.bytes));
}

/// The id of an object of [type] and [size] whose body arrives in pieces, so
/// a body too large to hold is hashed without ever being whole.
final class GitObjectHasher {
  GitObjectHasher(GitObjectType type, this.size) {
    _sink = sha1.startChunkedConversion(_digest)
      ..add(ascii.encode('${type.wireName} $size'))
      ..add(const [0]);
  }

  /// The body length the header declares.
  final int size;
  final DigestCollector _digest = DigestCollector();
  late final ByteConversionSink _sink;
  int _added = 0;

  void add(List<int> chunk) {
    _added += chunk.length;
    _sink.add(chunk);
  }

  /// The id. Throws [FormatException] when the bytes added are not [size].
  GitObjectId close() {
    if (_added != size) {
      throw FormatException('Object declared $size bytes but had $_added');
    }
    _sink.close();
    return GitObjectId(Uint8List.fromList(_digest.value!.bytes));
  }
}

/// Collects the single digest a chunked hash conversion emits (the crypto
/// package does not export a sink for it).
final class DigestCollector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
