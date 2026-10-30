import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/s3_server_fields.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Checks a WebDAV server before it is saved, returning the config to save.
/// The sync settings write a probe file; a shared library reaches its
/// folder read only, since a club may hand out logins that cannot write.
typedef WebDavCheck = Future<WebDavConfig> Function(WebDavConfig config);

/// The one "My own server" form (spec section 7.5): S3-compatible or WebDAV,
/// today's fields, Check connection and Save. New servers start as their
/// sync-role row; an [existing] account is pre-filled from what this device
/// holds, or from its synced location with the secret left to type.
class OwnServerForm extends ConsumerStatefulWidget {
  const OwnServerForm({
    super.key,
    this.existing,
    this.kinds = const {AccountKind.s3, AccountKind.webdav},
    this.showSyncFolder = false,
    this.webdavCheck,
    required this.onSaved,
  });

  final AccountGroup? existing;
  final Set<AccountKind> kinds;

  /// Shows the sync folder under Advanced, where the account is the sync
  /// account and its folder can be changed as on today's settings pages.
  final bool showSyncFolder;

  /// How a WebDAV server is checked on Check and Save; null runs the sync
  /// settings' write probe.
  final WebDavCheck? webdavCheck;

  /// The row the save wrote: the server's sync-role row for a new server,
  /// or the row of an existing account in the submitted folder. Awaited
  /// before the form is usable again, so what follows a save (pointing sync
  /// at it) finishes, and fails, inside the save.
  final Future<void> Function(ConnectedAccount row) onSaved;

  @override
  ConsumerState<OwnServerForm> createState() => _OwnServerFormState();
}

class _OwnServerFormState extends ConsumerState<OwnServerForm> {
  final _formKey = GlobalKey<FormState>();
  final _s3 = S3FormController();
  final _webdav = WebDavFormController();
  late AccountKind _kind;
  bool _busy = false;

  /// The config the form was filled from on this device, so a save replaces
  /// only the rows that held these keys (not a club's own keys on a library
  /// folder of the same server).
  S3Config? _storedS3;
  WebDavConfig? _storedWebDav;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? widget.kinds.first;
    if (existing != null) _prefill(existing);
  }

  /// This device's stored config when it holds one (editing a signed-in
  /// account), else the synced location with empty secrets (signing in).
  /// The sync row's folder first, so a sign-in never starts from a photos
  /// or library folder.
  Future<void> _prefill(AccountGroup group) async {
    final service = ref.read(accountGroupServiceProvider);
    final syncRow = group.syncRowHere ?? group.rowFor(AccountRole.sync);
    final location =
        (syncRow == null ? null : group.locationOf(syncRow.id)) ??
        group.locations.values.firstOrNull;
    switch (group.kind) {
      case AccountKind.s3:
        final stored = await service.storedS3For(group);
        _storedS3 = stored;
        final config =
            stored ??
            (location is S3AccountLocation
                ? location.toConfig(accessKeyId: '', secretAccessKey: '')
                : null);
        if (config != null && mounted && !_s3.hasTyping) _s3.load(config);
      case AccountKind.webdav:
        final stored = await service.storedWebDavFor(group);
        _storedWebDav = stored;
        final config =
            stored ??
            (location is WebDavAccountLocation
                ? location.toConfig(password: '')
                : null);
        if (config != null && mounted && !_webdav.userEdited) {
          _webdav.load(config);
        }
      default:
        break;
    }
  }

  @override
  void dispose() {
    _s3.dispose();
    _webdav.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: isError
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      if (_kind == AccountKind.s3) {
        String? detected;
        await ref
            .read(s3StorageProviderInstanceProvider)
            .testConnection(
              _s3.build(),
              onRegionCorrected: (region) => detected = region,
            );
        if (!mounted) return;
        final region = detected;
        if (region != null) {
          _s3.region.text = region;
          _snack(l10n.settings_s3Config_test_regionDetected(region));
        } else {
          _snack(l10n.settings_s3Config_test_success);
        }
      } else {
        await runWithCertificateTrust(context, _webdav, _webdavCheck);
        _snack(l10n.settings_webdavConfig_test_success);
      }
    } on WebDavException catch (e) {
      _snack(webDavErrorText(l10n, e), isError: true);
    } on CloudStorageException catch (e) {
      _snack(e.displayMessage, isError: true);
    } catch (e) {
      _snack(
        '${l10n.settings_s3Config_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final service = ref.read(accountGroupServiceProvider);
    setState(() => _busy = true);
    try {
      final row = _kind == AccountKind.s3
          ? await _saveS3(service, _s3.build())
          : await runWithCertificateTrust(context, _webdav, (config) async {
              await _webdavCheck(config);
              return _saveWebDav(service, config);
            });
      if (!mounted) return;
      _snack(l10n.settings_accounts_saved);
      await widget.onSaved(row);
    } on WebDavException catch (e) {
      _snack(webDavErrorText(l10n, e), isError: true);
    } on CloudStorageException catch (e) {
      _snack(e.displayMessage, isError: true);
    } catch (e) {
      _snack(
        '${l10n.settings_s3Config_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<WebDavConfig> _webdavCheck(WebDavConfig config) =>
      (widget.webdavCheck ??
      ref.read(webdavStorageProviderInstanceProvider).testConnection)(config);

  /// The same server as [widget.existing] signs its rows in with the
  /// submitted settings and returns the row in the submitted folder; a
  /// folder no row holds yet is saved as its own row.
  Future<ConnectedAccount> _saveS3(
    AccountGroupService service,
    S3Config config,
  ) async {
    final existing = widget.existing;
    final location = S3AccountLocation.fromConfig(config);
    if (existing != null && location.serverKey == existing.key) {
      // The submitted settings, not only the keys: an edit of the region or
      // the addressing must survive the save.
      final signedIn = await service.storeServerConfig(
        existing,
        s3: config,
        previousS3: _storedS3,
      );
      final same = _rowInFolder(existing, location.folder);
      if (signedIn > 0 && same != null) return same;
    }
    return service.saveOwnServer(s3: config);
  }

  Future<ConnectedAccount> _saveWebDav(
    AccountGroupService service,
    WebDavConfig config,
  ) async {
    final existing = widget.existing;
    final location = WebDavAccountLocation.fromConfig(config);
    if (existing != null && location.serverKey == existing.key) {
      final signedIn = await service.storeServerConfig(
        existing,
        webdav: config,
        previousWebDav: _storedWebDav,
      );
      final same = _rowInFolder(existing, location.folder);
      if (signedIn > 0 && same != null) return same;
    }
    return service.saveOwnServer(webdav: config);
  }

  /// [group]'s row in [folder]: saving there needs no new row, and no
  /// relabel that would drop a library row's folder note.
  static ConnectedAccount? _rowInFolder(AccountGroup group, String folder) =>
      group.rows.firstWhereOrNull(
        (r) => group.locationOf(r.id)?.folder == folder,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choosable =
        widget.existing == null &&
        widget.kinds.contains(AccountKind.s3) &&
        widget.kinds.contains(AccountKind.webdav);
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (choosable) ...[
              SegmentedButton<AccountKind>(
                segments: [
                  ButtonSegment(
                    value: AccountKind.s3,
                    label: Text(l10n.settings_accounts_ownServer_s3),
                  ),
                  ButtonSegment(
                    value: AccountKind.webdav,
                    label: Text(l10n.settings_accounts_ownServer_webdav),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _kind = s.single),
              ),
              const SizedBox(height: 16),
            ],
            if (_kind == AccountKind.s3)
              S3ServerFields(
                controller: _s3,
                showPrefix: widget.showSyncFolder,
                keyPrefix: 'account-s3',
              )
            else
              WebDavServerFields(
                controller: _webdav,
                showFolder: widget.showSyncFolder,
                keyPrefix: 'account-webdav',
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('own-server-check'),
                  onPressed: _busy ? null : _check,
                  child: Text(l10n.settings_accounts_checkConnection),
                ),
                FilledButton(
                  key: const Key('own-server-save'),
                  onPressed: _busy ? null : _save,
                  child: Text(l10n.settings_accounts_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pushes the form on its own page and returns the row it saved, or null
/// when the diver backs out.
///
/// [rootNavigator] pushes over everything, as the first-run wizard needs:
/// with no diver yet, a go_router push would bounce back to the welcome
/// page.
Future<ConnectedAccount?> showOwnServerPage(
  BuildContext context, {
  AccountGroup? existing,
  Set<AccountKind> kinds = const {AccountKind.s3, AccountKind.webdav},
  bool rootNavigator = false,
  bool showSyncFolder = false,
  WebDavCheck? webdavCheck,
}) =>
    Navigator.of(context, rootNavigator: rootNavigator).push<ConnectedAccount>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              existing == null
                  ? context.l10n.settings_accounts_ownServer_title
                  : context.l10n.settings_accounts_signInTo(existing.label),
            ),
          ),
          body: SingleChildScrollView(
            child: OwnServerForm(
              existing: existing,
              kinds: kinds,
              showSyncFolder: showSyncFolder,
              webdavCheck: webdavCheck,
              onSaved: (row) async => Navigator.of(context).pop(row),
            ),
          ),
        ),
      ),
    );
