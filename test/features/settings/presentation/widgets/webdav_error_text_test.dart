import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every code has localized text', () {
    for (final code in WebDavErrorCode.values) {
      final text = webDavErrorText(l10n, WebDavException('x', code: code));
      expect(text, isNotEmpty, reason: code.name);
    }
  });

  test('placeholders and the server detail are carried', () {
    final redirect = WebDavException(
      'x',
      code: WebDavErrorCode.redirected,
      location: 'https://new/',
      cause: 'HTTP 301 PROPFIND /dav/',
    );
    expect(webDavErrorText(l10n, redirect), contains('https://new/'));
    expect(webDavErrorText(l10n, redirect), contains('HTTP 301'));
    final big = WebDavException(
      'x',
      code: WebDavErrorCode.tooLarge,
      sizeBytes: 3 * 1024 * 1024,
    );
    expect(webDavErrorText(l10n, big), contains('3 MB'));
  });

  test('the unreachable host comes from the exception, not its wording', () {
    final e = WebDavException(
      'anything at all',
      code: WebDavErrorCode.unreachable,
      host: 'nas.local',
    );
    expect(webDavErrorText(l10n, e), contains('nas.local'));
  });
}
