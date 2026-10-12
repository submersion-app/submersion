import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  test('a WebDAV failure reads as the WebDAV settings put it', () {
    final error = WebDavException(
      'Unauthorized',
      code: WebDavErrorCode.unauthorized,
    );
    expect(
      libraryErrorText(de, error),
      de.settings_webdavConfig_error_unauthorized,
    );
  });

  test('another storage failure keeps the provider message', () {
    expect(
      libraryErrorText(de, const CloudStorageException('S3 is not configured')),
      'S3 is not configured',
    );
  });
}
