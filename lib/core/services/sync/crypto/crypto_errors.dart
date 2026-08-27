/// The cloud library is encrypted and this device holds no (matching) key.
///
/// Carriers of this exception halt sync with
/// SyncResultStatus.awaitingPassphrase instead of surfacing a raw error.
class SyncEncryptionRequired implements Exception {
  final String? libraryKeyId;
  final String message;

  const SyncEncryptionRequired({
    this.libraryKeyId,
    this.message = 'The cloud library is encrypted',
  });

  @override
  String toString() => 'SyncEncryptionRequired($libraryKeyId): $message';
}

/// An SBE1 envelope failed structural parsing or authentication. Treated
/// like a checksum failure: transient-stop, never a silent fallback.
class EnvelopeCorruptException implements Exception {
  final String message;

  const EnvelopeCorruptException(this.message);

  @override
  String toString() => 'EnvelopeCorruptException: $message';
}
