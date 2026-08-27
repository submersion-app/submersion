import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

/// Collapses duplicate `connected_accounts` rows onto their deterministic
/// ids.
///
/// Rows created before deterministic ids existed carry random UUIDv4s, so
/// the same endpoint appears once per connect and once per device. This pass
/// is anchor-based rather than group-and-elect: legacy labels carry only
/// `bucket @ host` with no prefix, so grouping on the label would merge a
/// sync-S3 and a media-S3 account that share a bucket - two accounts the
/// identity scheme deliberately keeps apart.
///
/// An anchor is a row something actually points at. There are at most two:
/// the sync account (`sync_metadata.sync_account_id`) and the media store
/// account (`media_store_account_id`). Each is migrated to the canonical id
/// derived from its own config. Every other non-Lightroom row is referenced
/// by nothing and its keychain blob is a copy, so it is deleted.
///
/// Runs on every launch rather than behind a done flag, so it also heals
/// rows that arrive later from a device still on an older build. It performs
/// no writes when there is nothing to collapse.
class AccountDeduplicator {
  AccountDeduplicator({
    required SharedPreferences prefs,
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
    SyncRepository? syncRepository,
    EstablishedProviderStore? established,
    S3CredentialsStore? syncS3,
    S3CredentialsStore? mediaS3,
  }) : _prefs = prefs,
       _accounts = accounts ?? ConnectedAccountsRepository(),
       _credentials = credentials ?? AccountCredentialsStore(),
       _syncRepository = syncRepository ?? SyncRepository(),
       _established = established ?? EstablishedProviderStore(prefs),
       _syncS3 = syncS3 ?? S3CredentialsStore(storageKey: _syncS3Key),
       _mediaS3 = mediaS3 ?? S3CredentialsStore(storageKey: _mediaS3Key);

  static final _log = LoggerService.forClass(AccountDeduplicator);

  static const String _syncS3Key = 'sync_s3_config';
  static const String _mediaS3Key = 'media_store_s3_config';
  static const String _mediaAccountIdKey = 'media_store_account_id';

  final SharedPreferences _prefs;
  final ConnectedAccountsRepository _accounts;
  final AccountCredentialsStore _credentials;
  final SyncRepository _syncRepository;
  final EstablishedProviderStore _established;
  final S3CredentialsStore _syncS3;
  final S3CredentialsStore _mediaS3;

  Future<void> run() async {
    try {
      await _run();
    } catch (e, stackTrace) {
      // A dedup failure must never block startup: the duplicates are a
      // cosmetic and hygiene problem, and the next launch retries.
      _log.error(
        'Account deduplication failed; will retry next launch',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _run() async {
    final all = await _accounts.getAll();
    final candidates = all
        .where((a) => a.kind != AccountKind.adobeLightroom)
        .toList();
    if (candidates.isEmpty) return;

    // Anchors first, so references are repointed before anything is deleted.
    final keep = <String>{};

    final syncCanonical = await _canonicalizeSyncAnchor();
    if (syncCanonical != null) keep.add(syncCanonical);

    final mediaCanonical = await _canonicalizeMediaAnchor();
    if (mediaCanonical != null) keep.add(mediaCanonical);

    // Everything else is inert: nothing points at it, and its credentials
    // blob is a copy of an anchor's.
    for (final account in candidates) {
      if (keep.contains(account.id)) continue;
      // The established marker gates sync's first-contact check, so it
      // carries only onto the SYNC canonical id. The media anchor plays no
      // part in that gate and must not inherit the marker.
      if (syncCanonical != null && _established.contains(account.id)) {
        await _established.add(syncCanonical);
      }
      await _accounts.delete(account.id);
    }
  }

  /// Migrates the sync account onto its canonical id and repoints
  /// `sync_metadata`. Returns the id to keep, or null when there is no sync
  /// anchor.
  Future<String?> _canonicalizeSyncAnchor() async {
    final id = await _syncRepository.getSyncAccountId();
    if (id == null) return null;
    final row = await _accounts.getById(id);
    if (row == null || row.kind == AccountKind.adobeLightroom) return null;

    final canonical = await _canonicalIdFor(row, _syncS3);
    if (canonical == null || canonical == row.id) return row.id;

    await _adopt(row, canonical);
    final providerType = row.kind.cloudProviderType;
    if (providerType != null) {
      await _syncRepository.setSyncAccount(
        accountId: canonical,
        providerType: providerType,
      );
    }
    return canonical;
  }

  /// Migrates the media store account onto its canonical id and repoints the
  /// attach pref. Returns the id to keep, or null when nothing is attached.
  Future<String?> _canonicalizeMediaAnchor() async {
    final id = _prefs.getString(_mediaAccountIdKey);
    if (id == null) return null;
    final row = await _accounts.getById(id);
    if (row == null || row.kind == AccountKind.adobeLightroom) return null;

    final canonical = await _canonicalIdFor(row, _mediaS3);
    if (canonical == null || canonical == row.id) return row.id;

    await _adopt(row, canonical);
    await _prefs.setString(_mediaAccountIdKey, canonical);
    return canonical;
  }

  /// The deterministic id for [row], or null when this device cannot resolve
  /// the endpoint (an S3 config it cannot read). Null means "leave it alone":
  /// a device that can read the config finishes the migration, and the
  /// deterministic id makes both devices agree afterwards.
  Future<String?> _canonicalIdFor(
    domain.ConnectedAccount row,
    S3CredentialsStore s3Store,
  ) async {
    if (row.kind == AccountKind.s3) {
      final config = await s3Store.load();
      if (config == null) return null;
      return accountIdFor(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(config),
      );
    }
    final key = naturalKeyForKind(row.kind);
    return key == null ? null : accountIdFor(kind: row.kind, naturalKey: key);
  }

  /// Copies [row] onto [canonicalId]: credentials first, then the row.
  ///
  /// The legacy row is left for the inert sweep to delete, so a crash
  /// between here and the sweep leaves a harmless extra row rather than a
  /// reference pointing at a tombstone.
  Future<void> _adopt(domain.ConnectedAccount row, String canonicalId) async {
    final blob = await _credentials.read(row.id);
    if (blob != null) await _credentials.write(canonicalId, blob);
    // ensureById rather than a read-then-create: another device may already
    // have published this very id (that is the point of deterministic ids),
    // so an inbound sync apply can land the row mid-pass.
    await _accounts.ensureById(
      id: canonicalId,
      kind: row.kind,
      label: row.label,
      accountIdentifier: row.accountIdentifier,
    );
    if (_established.contains(row.id)) {
      await _established.add(canonicalId);
    }
  }
}
