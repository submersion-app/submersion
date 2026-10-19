import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/storage_setup_sheet.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why [folder] cannot hold a library, or null when it can.
String? libraryFolderProblem(AppLocalizations l10n, String folder) {
  final f = folder.trim();
  if (SharedLibraryTransport.leavesLibraries(f)) {
    return l10n.settings_webdavConfig_validation_folder;
  }
  if (SharedLibraryTransport.startsReserved(f)) {
    return l10n.sharedLibrary_connect_reservedFolder;
  }
  if (SharedLibraryTransport.hasPolicyWildcards(f)) {
    return l10n.sharedLibrary_connect_folderChars;
  }
  return null;
}

/// The folder and the server a library is reached through, as the connect
/// page and the change-connection page pick them. The server is an account
/// from the account sheet (issue #3482); the library's own roster row, which
/// carries the folder, is resolved from both when a check or join runs.
class LibraryLocationController extends ChangeNotifier {
  LibraryLocationController({String initialPrefix = ''})
    : prefix = TextEditingController(text: initialPrefix),
      _initialFolder = initialPrefix.trim();

  final TextEditingController prefix;

  /// The library row a change of connection starts from ([seed]), used as
  /// is while its server and folder stay chosen (it may hold keys of its
  /// own).
  String? initialAccountId;
  String _initialFolder;

  /// The chosen server, or null before one is.
  AccountGroup? server;

  /// The row the last check went through ([probeAccount]), or the library's
  /// own row once [resolveAccount] has made it.
  ConnectedAccount? account;

  String get folder => prefix.text.trim();

  /// Starts a change of connection from [library]'s row and folder.
  void seed({required String folder, required String? accountId}) {
    prefix.text = folder;
    _initialFolder = folder.trim();
    initialAccountId = accountId;
  }

  void selectServer(AccountGroup? group) {
    server = group;
    account = null;
    notifyListeners();
  }

  /// A row to check the chosen server and folder through, without saving
  /// anything: the library's own row while nothing changed, a row already
  /// there for this folder that is signed in here, else any signed-in row
  /// of the server (a check reads the folder it is given, not the row's
  /// own). A row nothing here can place is used as is, as the old picker
  /// did. Throws [StateError] when nothing on the server is signed in here.
  ConnectedAccount? probeAccount() {
    final group = server;
    if (group == null) return account = null;
    final unchanged = _unchangedRow(group);
    if (unchanged != null) return account = unchanged;
    if (group.rows.every((r) => group.locationOf(r.id) == null)) {
      return account = group.rows.first;
    }
    bool signedIn(ConnectedAccount r) =>
        group.statusOf(r.id) == AccountStatus.signedIn;
    final existing = _rowInFolder(group);
    if (existing != null && signedIn(existing)) return account = existing;
    final any = group.rows.firstWhereOrNull(signedIn);
    if (any != null) return account = any;
    throw StateError('not signed in');
  }

  /// The library's own row, made only when the diver joins, creates or
  /// saves: the library's own row while nothing changed, a row already there
  /// for this folder (with whatever keys it holds), else a new library row
  /// on the server's keys.
  Future<ConnectedAccount?> resolveAccount(AccountGroupService service) async {
    final group = server;
    if (group == null) return account = null;
    final unchanged = _unchangedRow(group);
    if (unchanged != null) return account = unchanged;
    final existing = _rowInFolder(group);
    // A row nothing on this device can place (written before locations,
    // signed in elsewhere) cannot lend its server to a new folder; it is
    // used as is, as the account picker did before.
    if (existing == null &&
        group.rows.every((r) => group.locationOf(r.id) == null)) {
      return account = group.rows.first;
    }
    return account =
        existing ??
        await service.ensureRole(
          group,
          AccountRole.library,
          libraryFolder: folder,
        );
  }

  ConnectedAccount? _unchangedRow(AccountGroup group) {
    final initial = group.rows.firstWhereOrNull(
      (r) => r.id == initialAccountId,
    );
    return initial != null && folder == _initialFolder ? initial : null;
  }

  /// The row already on the server for the typed folder, compared as the
  /// stored folders are written (segments trimmed, empty ones dropped).
  ConnectedAccount? _rowInFolder(AccountGroup group) {
    final where = _normalized(LibraryAccountSetup.libraryFolder(folder));
    return group.rows.firstWhereOrNull(
      (r) => _normalized(group.locationOf(r.id)?.folder ?? '') == where,
    );
  }

  static String _normalized(String folder) => folder
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join('/');

  @override
  void dispose() {
    prefix.dispose();
    super.dispose();
  }
}

/// The server accounts a library can live on: S3 and WebDAV, as today.
const libraryAccountKinds = {AccountKind.s3, AccountKind.webdav};

/// The [accountGroupsOfKindsProvider] key for [libraryAccountKinds].
final libraryKindsKey = accountKindsKey(libraryAccountKinds);

/// The S3 and WebDAV accounts among [groups].
List<AccountGroup> libraryServers(List<AccountGroup> groups) => [
  for (final g in groups)
    if (libraryAccountKinds.contains(g.kind)) g,
];

/// The folder field (with the storage setup guide) and the server the
/// library lives on, picked through the account sheet (issue #3482).
/// [onEdited] runs whenever the location changes, so a caller can drop a
/// check made against the old one.
class LibraryLocationFields extends ConsumerStatefulWidget {
  const LibraryLocationFields({
    super.key,
    required this.controller,
    required this.servers,
    required this.onEdited,
    this.enabled = true,
  });

  final LibraryLocationController controller;

  /// False while the caller is busy (checking, joining): the location waits.
  final bool enabled;
  final List<AccountGroup> servers;
  final VoidCallback onEdited;

  @override
  ConsumerState<LibraryLocationFields> createState() =>
      _LibraryLocationFieldsState();
}

class _LibraryLocationFieldsState extends ConsumerState<LibraryLocationFields> {
  LibraryLocationController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The chosen server as the latest accounts list has it (a sign-in
    // changes its state); first pick the library's own, else the first.
    final list = widget.servers;
    final key = _c.server?.key;
    // A server signed in here first, so Check has keys to use.
    final current =
        list.firstWhereOrNull((g) => g.key == key) ??
        list.holding(_c.initialAccountId) ??
        list.firstWhereOrNull((g) => g.signedInHere) ??
        list.firstOrNull;
    if (key != null && current?.key != key) {
      // The chosen server is gone (removed elsewhere): what was checked
      // against it no longer holds, so the page drops it after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _c.selectServer(current);
        widget.onEdited();
      });
    }
    _c.server = current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _folderField(),
        const SizedBox(height: 12),
        if (current != null)
          ListTile(
            key: const Key('library-server'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(accountKindIcon(current.kind)),
            title: Text(l10n.settings_sync_using(current.label)),
            subtitle: TileSubtitleAction(
              actionKey: const Key('library-server-change'),
              label: l10n.settings_sync_change,
              onPressed: widget.enabled ? _change : null,
            ),
          ),
      ],
    );
  }

  Future<void> _change() async {
    final choice = await showAccountSheet(
      context,
      allowedKinds: libraryAccountKinds,
      currentKey: _c.server?.key,
      webdavCheck: ref.read(libraryAccountSetupProvider).reachWebDav,
    );
    if (choice == null || !mounted) return;
    _c.selectServer(choice);
    widget.onEdited();
  }

  Widget _folderField() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('library-prefix'),
          controller: _c.prefix,
          // A check running against this location must not find it
          // changed under its result.
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: l10n.sharedLibrary_connect_prefix_label,
            helperText: l10n.sharedLibrary_connect_prefix_help,
            helperMaxLines: 3,
          ),
          onChanged: (_) => widget.onEdited(),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.help_outline),
            label: Text(l10n.sharedLibrary_setup_title),
            onPressed: () async {
              final bucket = _bucketForGuide();
              await showStorageSetupSheet(
                context,
                bucket: bucket,
                folder: _c.prefix.text,
              );
            },
          ),
        ),
      ],
    );
  }

  /// The bucket the example policies name: the chosen S3 server's own (its
  /// locations include this device's stored settings), else a placeholder.
  String _bucketForGuide() =>
      _c.server?.locations.values
          .whereType<S3AccountLocation>()
          .firstOrNull
          ?.bucket ??
      'your-bucket';
}

/// Opens the account sheet's add section for a library server and returns
/// the account added, or null.
/// A library may hand out WebDAV logins that cannot write, so the server is
/// reached read only, never with the sync settings' write probe.
Future<AccountGroup?> addLibraryServer(BuildContext context) =>
    showAccountSheet(
      context,
      allowedKinds: libraryAccountKinds,
      addOnly: true,
      webdavCheck: ProviderScope.containerOf(
        context,
        listen: false,
      ).read(libraryAccountSetupProvider).reachWebDav,
    );
