/// The selected backup artifact is encrypted (SBE1 framed) and no cached
/// key matches, so a passphrase or recovery code is required. The restore
/// UI catches this, prompts, and retries with `encryptionSecret`.
class BackupEncryptedException implements Exception {
  const BackupEncryptedException();

  @override
  String toString() => 'BackupEncryptedException: backup requires a passphrase';
}
