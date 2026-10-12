import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final details = WebDavCertificateDetails(
    host: 'nas.local',
    port: 5006,
    sha256: 'ab' * 32,
    subject: 'CN=nas.local',
    issuer: 'CN=Home NAS',
    startValidity: DateTime.utc(2026),
    endValidity: DateTime.utc(2027, 3, 1),
  );

  bool? result;

  Future<void> open(
    WidgetTester tester,
    WebDavUntrustedCertificateException e,
  ) async {
    result = null;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showWebDavTrustDialog(context, e),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows host, fingerprint, subject and issuer; trust returns true',
    (tester) async {
      await open(tester, WebDavUntrustedCertificateException(details));
      expect(find.textContaining('nas.local'), findsWidgets);
      expect(find.text(formatFingerprint('ab' * 32)), findsOneWidget);
      expect(find.text('CN=Home NAS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('webdav-trust')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );

  testWidgets('cancel returns false', (tester) async {
    await open(tester, WebDavUntrustedCertificateException(details));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('a changed certificate shows the previous fingerprint', (
    tester,
  ) async {
    await open(
      tester,
      WebDavUntrustedCertificateException(details, pinnedSha256: 'cd' * 32),
    );
    expect(find.text(formatFingerprint('cd' * 32)), findsOneWidget);
    expect(find.textContaining('changed since you trusted it'), findsOneWidget);
  });
}
