# Connected Accounts deduplication

Date: 2026-07-24

## Problem

The Connected Accounts page shows the same endpoint many times. The page is
not at fault: it renders `ConnectedAccountsRepository.getAll()` verbatim, and
the rows really are duplicated in `connected_accounts`.

Evidence from the development database (11 rows):

| kind | label | count |
| ---- | ----- | ----- |
| s3 | `submersion-sync @ 149b84f6...r2.cloudflarestorage.com` | 9 |
| icloud | `iCloud` | 2 |

Every row carries a distinct UUIDv4, `created_at == updated_at`, and
`account_identifier` NULL. The HLC column shows two distinct node ids, so
six S3 rows were minted on one device and three on another; the two iCloud
rows are one per device.

## Root cause

`connected_accounts` rows have no natural identity. Row identity is a
per-device random `Uuid().v4()`, and "does this account already exist?" is
answered either by `getByKind` (kind-only, local-only) or not at all. Two
consequences, both observed:

1. **S3 has no dedup at all.** `MediaStoreService.connectS3` creates a row on
   every connect, and `ensureAccountForProviderType`'s S3 branch creates a row
   whenever the persisted sync account is of another kind - which is exactly
   what happens each time sync flips S3 to iCloud and back.
2. **`getByKind` dedup is local-only on a replicated table.** Two devices
   independently mint different UUIDs for the same logical account, and sync
   unions them. This is the iCloud pair.

`connected_accounts` already has an `account_identifier` column, populated
only for Lightroom catalog ids.

## Design

### 1. Deterministic account identity

New `lib/core/services/accounts/account_identity.dart`:

```
kConnectedAccountNamespace = 'c622faae-974f-4310-a5e7-36c2fb773684'

naturalKeyFor(kind, {S3Config? s3}) ->
  s3                          : '${s3.displayHost}|${s3.bucket}|${s3.prefix}'
  icloud, dropbox, googledrive: kind.name
  adobeLightroom              : null (excluded)

accountIdFor(kind, naturalKey) ->
  const Uuid().v5(kConnectedAccountNamespace, '${kind.name}:$naturalKey')
```

This follows the existing UUIDv5 idiom in
`lib/features/data_quality/domain/entities/quality_finding.dart`.

The primary key becomes the uniqueness constraint. Two devices connecting the
same endpoint independently compute the same id, so sync's upsert-by-id
collapses them with no coordination. No DB unique index is added: a unique
constraint on a replicated table would make an inbound sync insert throw
rather than merge.

`displayHost` rather than raw `endpoint` is used so that AWS-proper (empty
endpoint, host derived from region) and an explicit endpoint for the same
bucket do not split into two accounts.

The S3 key includes `prefix`, which preserves the separation documented at
`media_store_service.dart:204` ("the media store S3 config is independent
from sync's by design"): sync defaults to prefix `submersion-sync/` and the
media store uses its own, so the same bucket yields two accounts.

**Lightroom is excluded.** The v107 DB migration preserved Lightroom ids
because scan state and suggestion rows key on them, and Lightroom already has
real per-catalog identity in `account_identifier`. Rewriting those ids would
orphan that data.

No schema change, so no schema version bump.

### 2. Repository `ensure()` and the creation sites

```dart
Future<ConnectedAccount> ensure({
  required AccountKind kind,
  required String naturalKey,
  required String label,
}) async {
  final id = accountIdFor(kind, naturalKey);
  final existing = await getById(id);
  if (existing != null) {
    if (existing.label != label) await updateLabels(id, label: label);
    return existing.copyWith(label: label);
  }
  return create(id: id, kind: kind, label: label);
}
```

`create()` already accepts an injectable `id`, so its signature is unchanged.
The label refresh keeps a renamed bucket current without minting a row.

Creation sites change as follows:

| Site | Today | After |
| ---- | ----- | ----- |
| `media_store_service.dart:211` `connectS3` | unconditional `create` | `ensure(s3, key(config), '$bucket @ $host')`; an explicit `accountId` still wins when it is an S3 account |
| `media_store_service.dart:279` `_connectManaged` | `getByKind ?? create` | `ensure(kind, kind.name, displayHint)` |
| `sync_providers.dart:270` S3 branch | unconditional `create` | read `S3CredentialsStore.storageKey`, then `ensure(s3, key(config), ...)`; if the config is unreadable, keep today's behaviour |
| `sync_providers.dart:276` managed branch | `getByKind ?? create` | `ensure(kind, kind.name, providerName)` |
| `account_startup_migration.dart:87,137,148` | `create` | route through `ensure()` |

`getByKind()` remains for reads (resolving "the iCloud account") and is
removed from write paths. A local-only query is fine for answering a
question and wrong for deciding whether to insert into a replicated table.

The explicit-`accountId` branch in `connectS3` is retained: the media hub
passes a specific account when re-attaching, and redirecting that to a
natural-key match would change which endpoint the store attaches to.

`sync_providers.dart`'s S3 branch is the only site needing new data - it
receives a `CloudProviderType` only. It gains a read of the legacy S3
credentials blob, already the documented source of truth on that path
(`_mirrorLegacyCredentials` reads the same key).

### 3. Startup reconciliation of existing duplicates

New `lib/core/services/accounts/account_deduplicator.dart`, run from
`startup_page.dart:356` immediately after `AccountStartupMigration`. It runs
every launch rather than being done-flag gated, so it also heals rows that
arrive later from a device still on an older build, and short-circuits when
there is nothing to do.

The pass is **anchor-based** rather than group-and-elect. Grouping legacy rows
by `(kind, label)` is not safe: legacy labels carry only `bucket @ host` with
no prefix, so a sync-S3 and a media-S3 account sharing one bucket have
identical labels, and grouping on the label would merge two accounts that
section 1 deliberately keeps separate.

**Anchors.** An anchor is a row some piece of state actually points at. There
are at most two non-Lightroom anchors on a device:

| Anchor | Reference | Natural key recomputed from |
| ------ | --------- | --------------------------- |
| sync | `sync_metadata.sync_account_id` | the sync S3 config, else `kind.name` for managed kinds |
| media store | `media_store_account_id` pref | the media store S3 config, else `kind.name` |

Each anchor is migrated to its own canonical deterministic id, computed from
its own config. Two anchors that resolve to the same natural key (same host,
bucket and prefix) legitimately collapse into one row; two that differ stay
two rows. This is what makes the pass correct for a shared bucket.

**Everything else is inert.** Any remaining non-Lightroom row is referenced by
nothing: not by `sync_metadata`, not by the media pref, and its keychain blob
is a copy rather than a unique credential. Those rows are deleted. No
attribution decision is needed for them, which is precisely why the label
ambiguity above stops mattering once the anchors are handled first.

**Order of operations.** References are repointed before any deletion, so a
crash mid-pass never strands a reference on a deleted row:

1. copy the anchor's keychain blob to the canonical id
   (`AccountCredentialsStore.write`)
2. write the canonical row (`ensure()`, carrying the anchor's label)
3. `sync_metadata.sync_account_id` to canonical, when the sync anchor moved
4. `media_store_account_id` pref to canonical, when the media anchor moved
5. `EstablishedProviderStore.add(canonicalId)` when any row being removed was
   established
6. delete every non-canonical, non-Lightroom row via
   `ConnectedAccountsRepository.delete()`, which already logs tombstones

`delete()` writes a tombstone, and a tombstone for a row `sync_metadata` still
points at would leave every peer resolving sync to a nonexistent account, so
this ordering is load-bearing rather than stylistic.

**Rows this device cannot attribute.** If an anchor's S3 config is not
readable on this device, that anchor keeps its existing id and is left alone;
its inert siblings are still removed. A device that can read the config
finishes the migration, and the deterministic id makes both devices agree.

Lightroom rows are skipped entirely, per section 1.

**Idempotence.** A second run finds each anchor already at its canonical id
and no inert rows, and exits without writes.

## Testing

Tests are written before the implementation, per the project TDD rule.

- `account_identity_test.dart`: same config yields the same id; a prefix change
  yields a different id; AWS-proper and explicit endpoint for the same bucket
  yield the same id.
- `connected_accounts_repository_test.dart`: `ensure()` twice yields one row;
  label drift updates in place without inserting.
- `account_deduplicator_test.dart`: seeded with the 11 observed rows, yields
  1 S3 + 1 iCloud, `sync_metadata` repointed, 10 tombstones logged; a second
  run is a no-op; Lightroom rows untouched; a sync anchor and a media anchor
  sharing a bucket but differing in prefix survive as two rows; an anchor
  whose S3 config is unreadable keeps its id while its inert siblings go.
- Regression: `connectS3` called twice with an identical config yields one
  account row.

## Out of scope

- Any change to how Lightroom accounts are identified or deduplicated.
- A "Merge duplicates" UI action. The startup pass is automatic; a manual
  trigger can be added later if duplicates are ever observed post-fix.
- Schema changes. No new column and no unique index are introduced.
