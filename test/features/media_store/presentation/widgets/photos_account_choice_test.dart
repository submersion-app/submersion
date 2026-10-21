// Issue #3482: what choosing an account for the photo copies does, and the
// text the sheet shows for it, come from one decision.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_account_choice.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _t = DateTime.utc(2026);

AccountGroup _group(String id, AccountKind kind, String label) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  statusById: {id: AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

MediaStoreDescriptor _store({String? accountId, String type = 'dropbox'}) => (
  id: 'store-1',
  providerType: type,
  displayHint: 'Dropbox',
  lastSweepAt: null,
  accountId: accountId,
);

const PhotosChoiceFacts _noFacts = (attachedAccountId: null, heldOnlyHere: 0);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final dropbox = _group('db-row', AccountKind.dropbox, 'Dropbox');
  final drive = _group('gd-row', AccountKind.googledrive, 'Google Drive');
  final dropbox2 = _group('db-2', AccountKind.dropbox, 'Dropbox');

  group('an attached device', () {
    test('re-choosing the account its attachment names is no switch, even '
        'when the group is unknown', () {
      const copies = (
        attached: true,
        store: null,
        group: null,
        label: 'Dropbox',
      );
      const facts = (attachedAccountId: 'db-row', heldOnlyHere: 0);

      expect(isPhotosSwitch(copies, facts, dropbox), isFalse);
      expect(photosChoiceConsequence(l10n, copies, facts, dropbox), isNull);
    });

    test('another row of the same name is a switch, and says so', () {
      const copies = (
        attached: true,
        store: null,
        group: null,
        label: 'Dropbox',
      );
      const facts = (attachedAccountId: 'db-row', heldOnlyHere: 0);

      expect(isPhotosSwitch(copies, facts, dropbox2), isTrue);
      expect(
        photosChoiceConsequence(l10n, copies, facts, dropbox2),
        l10n.settings_photos_switchConsequence('Dropbox', 'Dropbox'),
      );
    });

    test('with no name for the copies, a switch still explains itself', () {
      const copies = (attached: true, store: null, group: null, label: null);
      const facts = (attachedAccountId: 'db-row', heldOnlyHere: 0);

      expect(isPhotosSwitch(copies, facts, drive), isTrue);
      expect(
        photosChoiceConsequence(l10n, copies, facts, drive),
        l10n.settings_photos_switchConsequenceUnnamed('Google Drive'),
      );
    });

    test('a switch warns about photos only the current copies hold', () {
      final copies = (
        attached: true,
        store: null,
        group: dropbox,
        label: 'Dropbox',
      );
      const facts = (attachedAccountId: 'db-row', heldOnlyHere: 3);

      final text = photosChoiceConsequence(l10n, copies, facts, drive)!;

      expect(text, contains(l10n.settings_photos_switchHeldOnly(3)));
    });

    test('an attachment known only by name joins by name, said once', () {
      const copies = (
        attached: true,
        store: null,
        group: null,
        label: 'Dropbox',
      );

      expect(isPhotosSwitch(copies, _noFacts, dropbox), isFalse);
      expect(
        photosChoiceConsequence(l10n, copies, _noFacts, dropbox),
        l10n.settings_photos_joinConsequence('Dropbox'),
      );
    });
  });

  group('a device not attached yet', () {
    test('an account of another kind than an unrecorded store starts '
        'separate copies', () {
      final copies = (
        attached: false,
        store: _store(),
        group: null,
        label: 'Dropbox',
      );

      expect(
        photosChoiceConsequence(l10n, copies, _noFacts, drive),
        l10n.settings_photos_separateConsequence('Dropbox', 'Google Drive'),
      );
    });

    test('the same kind and name as an unrecorded store joins it', () {
      final copies = (
        attached: false,
        store: _store(),
        group: null,
        label: 'Dropbox',
      );

      expect(photosChoiceConsequence(l10n, copies, _noFacts, dropbox), isNull);
    });

    test('the recorded account joins; another starts separate copies', () {
      final copies = (
        attached: false,
        store: _store(accountId: 'db-row'),
        group: dropbox,
        label: 'Dropbox',
      );

      expect(photosChoiceConsequence(l10n, copies, _noFacts, dropbox), isNull);
      expect(
        photosChoiceConsequence(l10n, copies, _noFacts, drive),
        l10n.settings_photos_separateConsequence('Dropbox', 'Google Drive'),
      );
    });
  });

  group('attach failures', () {
    test('an account with no keys here asks to sign in', () {
      expect(
        photosAttachErrorText(
          l10n,
          const MediaStoreAccountUnusable('Dropbox is not signed in'),
          dropbox,
        ),
        l10n.settings_accounts_signInTo('Dropbox'),
      );
    });

    test('a WebDAV failure gives the server reason', () {
      final cause = WebDavException(
        'down',
        code: WebDavErrorCode.unreachable,
        host: 'nas.local',
      );

      expect(
        photosAttachErrorText(
          l10n,
          MediaStoreException(
            'down',
            kind: MediaStoreErrorKind.transient,
            cause: cause,
          ),
          dropbox,
        ),
        startsWith(l10n.settings_webdavConfig_error_unreachable('nas.local')),
      );
    });

    test('an untrusted certificate is found inside the store error', () {
      final e = MediaStoreException(
        'untrusted',
        kind: MediaStoreErrorKind.auth,
        cause: WebDavUntrustedCertificateException(
          WebDavCertificateDetails(
            host: 'nas.local',
            port: 443,
            sha256: 'ab',
            subject: 'nas',
            issuer: 'nas',
            startValidity: _t,
            endValidity: _t,
          ),
        ),
      );

      expect(untrustedCertificateOf(e), isNotNull);
      expect(
        untrustedCertificateOf(
          const MediaStoreException('x', kind: MediaStoreErrorKind.auth),
        ),
        isNull,
      );
    });
  });
}
