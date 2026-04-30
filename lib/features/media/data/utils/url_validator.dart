// TODO(media): l10n — error strings here are user-visible.

sealed class UrlValidationResult {
  const UrlValidationResult();
}

class UrlValidationOk extends UrlValidationResult {
  const UrlValidationOk(this.uri);
  final Uri uri;
}

class UrlValidationEmpty extends UrlValidationResult {
  const UrlValidationEmpty();
}

class UrlValidationInvalid extends UrlValidationResult {
  const UrlValidationInvalid(this.message);
  final String message;
}

class UrlValidator {
  const UrlValidator._();

  static UrlValidationResult parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const UrlValidationEmpty();
    final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException catch (e) {
      return UrlValidationInvalid('Malformed URL: ${e.message}');
    }
    if (!uri.isAbsolute) {
      return const UrlValidationInvalid('URL must be absolute');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlValidationInvalid(
        'Unsupported scheme: ${uri.scheme} (must be http or https)',
      );
    }
    if (uri.host.isEmpty) {
      return const UrlValidationInvalid('URL must include a host');
    }
    return UrlValidationOk(uri);
  }
}
