import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized text for a WebDAV failure on the settings screens, followed by
/// the server's own detail when there is one (the same cause
/// `displayMessage` appends).
String webDavErrorText(AppLocalizations l10n, WebDavException e) {
  final text = switch (e.code) {
    WebDavErrorCode.invalidConfig =>
      l10n.settings_webdavConfig_error_invalidConfig,
    WebDavErrorCode.unauthorized =>
      l10n.settings_webdavConfig_error_unauthorized,
    WebDavErrorCode.forbidden => l10n.settings_webdavConfig_error_forbidden,
    WebDavErrorCode.notFound => l10n.settings_webdavConfig_error_notFound,
    WebDavErrorCode.notWebDav => l10n.settings_webdavConfig_error_notWebDav,
    WebDavErrorCode.redirected => l10n.settings_webdavConfig_error_redirected(
      e.location ?? '?',
    ),
    WebDavErrorCode.conflict => l10n.settings_webdavConfig_error_conflict,
    WebDavErrorCode.tooLarge => l10n.settings_webdavConfig_error_tooLarge(
      e.sizeBytes == null
          ? '?'
          : (e.sizeBytes! / (1024 * 1024)).round().toString(),
    ),
    WebDavErrorCode.insufficientStorage =>
      l10n.settings_webdavConfig_error_insufficientStorage,
    WebDavErrorCode.locked => l10n.settings_webdavConfig_error_locked,
    WebDavErrorCode.unreachable => l10n.settings_webdavConfig_error_unreachable(
      e.host ?? '?',
    ),
    WebDavErrorCode.server => l10n.settings_webdavConfig_error_server,
    WebDavErrorCode.unexpected => l10n.settings_webdavConfig_error_unexpected,
    WebDavErrorCode.untrustedCertificate =>
      l10n.settings_webdavConfig_error_untrusted,
  };
  final cause = e.cause;
  return cause == null ? text : '$text ($cause)';
}
