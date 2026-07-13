import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

/// One-time startup migration: seeds the connected_accounts roster from the
/// pre-account configuration (sync provider, media store attachment,
/// Lightroom connectors) and copies legacy keychain blobs to per-account
/// keys. No re-authentication: existing credentials are adopted in place.
/// Legacy blobs and prefs are never deleted (rollback safety).
class AccountStartupMigration {
  AccountStartupMigration({
    required SharedPreferences prefs,
    AppDatabase? database,
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
    SyncRepository? syncRepository,
    EstablishedProviderStore? established,
  }) : _prefs = prefs,
       _database = database,
       _accounts = accounts ?? ConnectedAccountsRepository(),
       _credentials = credentials ?? AccountCredentialsStore(),
       _syncRepository = syncRepository ?? SyncRepository(),
       _established = established ?? EstablishedProviderStore(prefs);

  static final _log = LoggerService.forClass(AccountStartupMigration);

  static const String doneFlagKey = 'accounts_migration_v1_done';

  /// Pre-account media store attach keys (formalized as constants on
  /// MediaStoreAttachState; literals here keep this file dependency-light).
  static const String _mediaProviderTypeKey = 'media_store_provider_type';
  static const String _mediaStoreIdKey = 'media_store_attached_store_id';
  static const String _mediaAccountIdKey = 'media_store_account_id';

  final SharedPreferences _prefs;
  final AppDatabase? _database;
  final ConnectedAccountsRepository _accounts;
  final AccountCredentialsStore _credentials;
  final SyncRepository _syncRepository;
  final EstablishedProviderStore _established;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  Future<void> run() async {
    if (_prefs.getBool(doneFlagKey) ?? false) return;
    try {
      await _migrateSyncProvider();
      await _migrateMediaStoreAttachment();
      await _adoptLightroomConnectors();
      await _prefs.setBool(doneFlagKey, true);
    } catch (e, stackTrace) {
      // Leave the flag unset so the next launch retries; every step is
      // individually idempotent (create-if-absent, copy-if-absent).
      _log.error(
        'Account migration failed; will retry next launch',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _migrateSyncProvider() async {
    final type = await _syncRepository.getCloudProvider();
    if (type == null) return;
    final kind = AccountKind.fromCloudProviderType(type);

    // Retry safety: a failed prior run may already have persisted the sync
    // account id AND created the (newer) media-S3 account, making
    // getByKind's newest-first pick wrong. The persisted id wins.
    domain.ConnectedAccount? account;
    final persistedId = await _syncRepository.getSyncAccountId();
    if (persistedId != null) {
      final persisted = await _accounts.getById(persistedId);
      if (persisted != null && persisted.kind == kind) account = persisted;
    }
    account ??= await _accounts.getByKind(kind);
    account ??= await _accounts.create(kind: kind, label: _labelFor(kind));

    switch (kind) {
      case AccountKind.s3:
        await _credentials.rekeyFromLegacy(
          legacyKey: 'sync_s3_config',
          accountId: account.id,
        );
      case AccountKind.dropbox:
        await _credentials.rekeyFromLegacy(
          legacyKey: 'sync_dropbox_auth',
          accountId: account.id,
        );
      case AccountKind.googledrive:
      case AccountKind.icloud:
      case AccountKind.adobeLightroom:
        break; // Session-managed or not a sync kind: nothing to re-key.
    }

    if (_established.contains(type.name)) {
      await _established.add(account.id);
    }

    await _db.customStatement(
      'UPDATE sync_metadata SET sync_account_id = ? WHERE id = ?',
      [account.id, 'global'],
    );
  }

  Future<void> _migrateMediaStoreAttachment() async {
    if (_prefs.getString(_mediaStoreIdKey) == null) return;
    final storedType = _prefs.getString(_mediaProviderTypeKey);
    // Attachments persisted before the provider type existed read as S3
    // (mirrors MediaStoreAttachState.attachedProviderType).
    final type = storedType == null
        ? CloudProviderType.s3
        : CloudProviderType.values.byName(storedType);
    final kind = AccountKind.fromCloudProviderType(type);

    // Retry safety: a failed prior run may already have created the media
    // account and written the pref; reuse it instead of duplicating rows.
    final existingId = _prefs.getString(_mediaAccountIdKey);
    if (existingId != null && await _accounts.getById(existingId) != null) {
      return;
    }

    final String accountId;
    if (kind == AccountKind.s3) {
      // The media store S3 config is independent from sync's by design:
      // always a separate account, never a reuse of the sync S3 account.
      final account = await _accounts.create(
        kind: AccountKind.s3,
        label: 'S3 media storage',
      );
      await _credentials.rekeyFromLegacy(
        legacyKey: 'media_store_s3_config',
        accountId: account.id,
      );
      accountId = account.id;
    } else {
      var account = await _accounts.getByKind(kind);
      account ??= await _accounts.create(kind: kind, label: _labelFor(kind));
      accountId = account.id;
    }
    await _prefs.setString(_mediaAccountIdKey, accountId);
  }

  Future<void> _adoptLightroomConnectors() async {
    // The v107 DB migration already copied connector_accounts rows into
    // connected_accounts (ids preserved) and dropped the old table. The
    // database cannot touch the keychain, so the credential copy happens
    // here: every adopted Lightroom account gets the legacy blob under its
    // own key (copy-if-absent, so re-runs and fresh sign-ins are safe).
    final all = await _accounts.getAll();
    for (final account in all) {
      if (account.kind != AccountKind.adobeLightroom) continue;
      await _credentials.rekeyFromLegacy(
        legacyKey: 'lightroom_auth',
        accountId: account.id,
      );
      // Rows adopted by the v107 SQL migration carry no HLC and were never
      // marked pending, so incremental changesets would skip them. Stamp
      // them here (idempotent: markRecordPending reuses the pending row).
      final hlcRow = await _db
          .customSelect(
            'SELECT hlc FROM connected_accounts WHERE id = ?',
            variables: [Variable.withString(account.id)],
          )
          .getSingleOrNull();
      if (hlcRow != null && hlcRow.data['hlc'] == null) {
        await _syncRepository.markRecordPending(
          entityType: 'connectedAccounts',
          recordId: account.id,
          localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
  }

  String _labelFor(AccountKind kind) => switch (kind) {
    AccountKind.dropbox => 'Dropbox',
    AccountKind.googledrive => 'Google Drive',
    AccountKind.icloud => 'iCloud',
    AccountKind.s3 => 'S3',
    AccountKind.adobeLightroom => 'Lightroom',
  };
}
