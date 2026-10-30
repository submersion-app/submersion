/// Where a Git repository lives and how to sign in to it.
///
/// [toString] never prints the token.
final class GitRemote {
  const GitRemote({
    required this.cloneUrl,
    required this.username,
    required this.token,
    this.pinnedCertSha256,
  });

  /// The repository's smart-HTTP address, ending in `.git` for most hosts.
  final Uri cloneUrl;
  final String username;
  final String token;

  /// Lowercase hex SHA-256 of a self-signed certificate the user trusted.
  final String? pinnedCertSha256;

  String get host => cloneUrl.host;
  int get port => cloneUrl.port;

  @override
  String toString() => 'GitRemote($username @ $cloneUrl)';
}
