import 'dart:convert';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';

/// Why a library's last sync failed.
enum LibrarySyncErrorCode {
  /// The account the library connects through is not on this device, and
  /// this device holds no keys to put it back.
  accountMissing,

  /// The account is on this device, which is signed out of it: its keys
  /// were removed here.
  accountSignedOut,

  /// The library's account is of a kind that cannot hold a library; the
  /// detail is the kind's name.
  accountUnsupported,

  /// No library at the stored location.
  notALibrary,

  /// Made by a test build before format 2: it can only be created again.
  retired,

  /// Made in a newer format; the detail is that format's number.
  needsNewerApp,

  /// Encrypted, and this device holds no key for it.
  needsPassphrase,

  /// Encrypted under a passphrase newer than the key held here.
  passphraseChanged,

  /// A WebDAV server's refusal, carried as [LibrarySyncError.webdav] so the
  /// page words it as the WebDAV settings do; the detail is its message.
  webdav,

  /// Anything else; the detail is the message the storage or the sync gave,
  /// which has no translation.
  failed,
}

/// A library's sync failure as its row stores it (issue #3563): a code and
/// an optional detail, so the page says it in the reader's language rather
/// than in the English it was written in.
class LibrarySyncError {
  const LibrarySyncError(this.code, {this.detail, this.webdav});

  LibrarySyncError.fromWebDav(WebDavException e)
    : this(LibrarySyncErrorCode.webdav, detail: e.displayMessage, webdav: e);

  /// Why the library's transport could not be built.
  factory LibrarySyncError.fromTransportError(StateError e) => switch (e) {
    LibraryAccountMissingError() => const LibrarySyncError(
      LibrarySyncErrorCode.accountMissing,
    ),
    LibraryAccountSignedOutError() => const LibrarySyncError(
      LibrarySyncErrorCode.accountSignedOut,
    ),
    LibraryAccountUnsupportedError(:final kindName) => LibrarySyncError(
      LibrarySyncErrorCode.accountUnsupported,
      detail: kindName,
    ),
    _ => LibrarySyncError(LibrarySyncErrorCode.failed, detail: e.message),
  };

  /// A sync that failed once under way: a WebDAV refusal keeps its code,
  /// other storage its display message, anything else its text.
  factory LibrarySyncError.fromSyncFailure(Object e) => switch (e) {
    WebDavException() => LibrarySyncError.fromWebDav(e),
    CloudStorageException() => LibrarySyncError(
      LibrarySyncErrorCode.failed,
      detail: e.displayMessage,
    ),
    _ => LibrarySyncError(LibrarySyncErrorCode.failed, detail: '$e'),
  };

  final LibrarySyncErrorCode code;
  final String? detail;

  /// For [LibrarySyncErrorCode.webdav]: the refusal as read back, with what
  /// its translation needs. Its cause comes back as text.
  final WebDavException? webdav;

  String encode() => jsonEncode({
    'code': code.name,
    if (detail != null) 'detail': detail,
    if (webdav case final e?)
      'webdav': {
        'code': e.code.name,
        'message': e.message,
        if (e.statusCode != null) 'statusCode': e.statusCode,
        if (e.location != null) 'location': e.location,
        if (e.sizeBytes != null) 'sizeBytes': e.sizeBytes,
        if (e.host != null) 'host': e.host,
        if (e.cause != null) 'cause': '${e.cause}',
      },
  });

  /// The failure [stored] in a library row. Text an older build wrote, and
  /// a code this build does not know, come back as [LibrarySyncErrorCode.failed]
  /// with the text to show as their detail.
  static LibrarySyncError decode(String stored) {
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      return LibrarySyncError(LibrarySyncErrorCode.failed, detail: stored);
    }
    if (json is! Map<String, dynamic> || json['code'] is! String) {
      return LibrarySyncError(LibrarySyncErrorCode.failed, detail: stored);
    }
    final detail = json['detail'] is String ? json['detail'] as String : null;
    final code = LibrarySyncErrorCode.values.asNameMap()[json['code']];
    if (code == null) {
      return LibrarySyncError(
        LibrarySyncErrorCode.failed,
        detail: detail ?? stored,
      );
    }
    return LibrarySyncError(
      code,
      detail: detail,
      webdav: _webDavFrom(json['webdav']),
    );
  }

  static WebDavException? _webDavFrom(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    T? as<T>(String key) => json[key] is T ? json[key] as T : null;
    return WebDavException(
      as<String>('message') ?? '',
      code:
          WebDavErrorCode.values.asNameMap()[json['code']] ??
          WebDavErrorCode.unexpected,
      statusCode: as<int>('statusCode'),
      location: as<String>('location'),
      sizeBytes: as<int>('sizeBytes'),
      host: as<String>('host'),
      cause: as<String>('cause'),
    );
  }

  @override
  String toString() => detail == null
      ? 'LibrarySyncError(${code.name})'
      : 'LibrarySyncError(${code.name}: $detail)';
}

/// The account a library connects through is not on this device, and this
/// device holds no keys to put it back (issue #3563).
class LibraryAccountMissingError extends StateError {
  LibraryAccountMissingError(String libraryName)
    : super('The account for $libraryName is no longer on this device');
}

/// The library's account is on this device, which is signed out of it.
class LibraryAccountSignedOutError extends StateError {
  LibraryAccountSignedOutError(String accountId)
    : super('This device is signed out of account $accountId');
}

/// The library's account is of a kind that cannot hold a library.
class LibraryAccountUnsupportedError extends StateError {
  LibraryAccountUnsupportedError(this.kindName)
    : super('$kindName accounts cannot back a library');

  final String kindName;
}
