import 'dart:convert';

import 'package:submersion/core/network/proxy/proxy_settings.dart';

/// Why a manual username and password cannot be used as entered.
enum ProxyCredentialsProblem {
  passwordRequired,
  usernameHasColon,
  usernameHasSemicolon,
  usernameHasEdgeWhitespace,
  passwordHasSemicolon,
  passwordHasEdgeWhitespace,
  tooLong,
}

extension ProxyCredentialsProblemField on ProxyCredentialsProblem {
  /// Whether the problem is the username's (shown under that field); the
  /// rest are the password's. [ProxyCredentialsProblem.tooLong] can be
  /// either, so the form decides it by which value is too long.
  bool get isUsernameProblem => switch (this) {
    ProxyCredentialsProblem.usernameHasColon ||
    ProxyCredentialsProblem.usernameHasSemicolon ||
    ProxyCredentialsProblem.usernameHasEdgeWhitespace => true,
    ProxyCredentialsProblem.passwordRequired ||
    ProxyCredentialsProblem.passwordHasSemicolon ||
    ProxyCredentialsProblem.passwordHasEdgeWhitespace ||
    ProxyCredentialsProblem.tooLong => false,
  };
}

/// Checks a manual username and password against what the transport can send.
///
/// HTTP credentials travel inside the dart:io proxy directive
/// (`PROXY user:pass@host:port`), the only way dart:io authenticates a CONNECT
/// tunnel. Its parser splits the whole directive on `;` (so neither value may
/// hold one), trims both values, ends the username at
/// the first `:` and rejects an empty password. SOCKS5 (RFC 1929) allows any
/// bytes but at most 255 of each, and no empty password.
///
/// Returns null when the pair is usable, or when there is no username.
ProxyCredentialsProblem? checkProxyCredentials(
  ProxyType type,
  String username,
  String password,
) {
  if (username.isEmpty) return null;
  if (password.isEmpty) return ProxyCredentialsProblem.passwordRequired;
  switch (type) {
    case ProxyType.http:
      if (username.contains(':')) {
        return ProxyCredentialsProblem.usernameHasColon;
      }
      if (username.contains(';')) {
        return ProxyCredentialsProblem.usernameHasSemicolon;
      }
      if (username.trim() != username) {
        return ProxyCredentialsProblem.usernameHasEdgeWhitespace;
      }
      if (password.contains(';')) {
        return ProxyCredentialsProblem.passwordHasSemicolon;
      }
      if (password.trim() != password) {
        return ProxyCredentialsProblem.passwordHasEdgeWhitespace;
      }
      return null;
    case ProxyType.socks5:
      if (utf8.encode(username).length > 255 ||
          utf8.encode(password).length > 255) {
        return ProxyCredentialsProblem.tooLong;
      }
      return null;
  }
}
