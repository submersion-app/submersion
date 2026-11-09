/// How a browser's video player streams an object from the media store
/// (issue #4162).
///
/// A browser's `<video>` element fetches its file itself and cannot send
/// headers, so a store either gives the player a URL that authorises itself
/// ([DirectLinkStore]: S3 presigning, Dropbox temporary links) or lets the
/// page read the object a byte range at a time ([RangeReadStore]: Google
/// Drive and WebDAV), which the media stream worker relays to the player.
///
/// Both are optional, apart from `MediaObjectStore`, so an adapter that
/// streams neither way (iCloud) and the test fakes stay as they are.
library;

import 'dart:typed_data';

/// A link a video player can fetch with no headers, until [expiresAt].
class DirectLink {
  const DirectLink({required this.url, required this.expiresAt});

  final Uri url;
  final DateTime expiresAt;
}

/// A store that can give a player a self-authorising link to an object.
abstract interface class DirectLinkStore {
  /// A fresh (or still fresh) link to [key].
  Future<DirectLink> directLink(String key);
}

/// A store that can read one byte range of an object. The object's total
/// size comes from the store's `head`.
abstract interface class RangeReadStore {
  /// Bytes [start] to [endInclusive] of [key], or fewer when the object
  /// ends first. Throws `MediaStoreException` (notFound) for a missing key.
  Future<Uint8List> readRange(
    String key, {
    required int start,
    required int endInclusive,
  });
}

/// The bytes [start] to [endInclusive] of a ranged GET's answer: a `206`
/// body is the range already, a `200` body (a server that ignores `Range`)
/// is the whole object and is cut down here.
Uint8List rangeOfAnswer(
  int status,
  Uint8List body, {
  required int start,
  required int endInclusive,
}) {
  if (status != 200) return body;
  if (start >= body.length) return Uint8List(0);
  final end = endInclusive + 1 < body.length ? endInclusive + 1 : body.length;
  return Uint8List.sublistView(body, start, end);
}

/// How long an S3 presigned video link stays valid.
const Duration kS3PresignLifetime = Duration(hours: 6);
