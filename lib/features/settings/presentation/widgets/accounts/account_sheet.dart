import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The one account picker (spec section 7.4): the diver's accounts, then
/// the kinds that can be added here. Returns the chosen account, signed in
/// on this device, or null when the diver backs out.
///
/// [allowedKinds] restricts both sections (shared libraries allow only S3
/// and WebDAV). When [consequenceOf] returns text for the choice, the sheet
/// shows it with Cancel and Continue before returning, so a choice with
/// consequences is explained before it takes effect.
Future<AccountGroup?> showAccountSheet(
  BuildContext context, {
  Set<AccountKind>? allowedKinds,
  String? currentKey,
  bool addOnly = false,
  String? Function(AccountGroup choice)? consequenceOf,
}) => showModalBottomSheet<AccountGroup>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.95,
    builder: (_, controller) => _AccountSheet(
      controller: controller,
      allowedKinds: allowedKinds,
      currentKey: currentKey,
      addOnly: addOnly,
      consequenceOf: consequenceOf,
    ),
  ),
);

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({
    required this.controller,
    required this.allowedKinds,
    required this.currentKey,
    required this.addOnly,
    required this.consequenceOf,
  });

  final ScrollController controller;
  final Set<AccountKind>? allowedKinds;
  final String? currentKey;
  final bool addOnly;
  final String? Function(AccountGroup)? consequenceOf;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  AccountGroup? _pending;
  String? _pendingText;
  bool _busy = false;

  bool _allowed(AccountKind kind) =>
      widget.allowedKinds?.contains(kind) ?? kind != AccountKind.adobeLightroom;

  bool _offerAllowed(AccountKindOffer offer) => switch (kindOfOffer(offer)) {
    final kind? => _allowed(kind),
    null => _allowed(AccountKind.s3) || _allowed(AccountKind.webdav),
  };

  Set<AccountKind> get _serverKinds => {
    for (final k in const [AccountKind.s3, AccountKind.webdav])
      if (_allowed(k)) k,
  };

  Future<void> _choose(AccountGroup group) async {
    setState(() => _busy = true);
    try {
      var chosen = group;
      if (group.status == AccountStatus.needsSignIn) {
        if (!await signInToGroup(context, ref, group)) return;
        final fresh = await ref.read(accountGroupsProvider.future);
        chosen = fresh.firstWhere(
          (g) => g.key == group.key,
          orElse: () => group,
        );
      }
      _offer(chosen);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(AccountKindOffer offer) async {
    setState(() => _busy = true);
    try {
      final row = await addAccountRow(context, ref, offer, kinds: _serverKinds);
      if (row == null) return;
      final groups = await ref.read(accountGroupsProvider.future);
      final group = groups.holding(row.id);
      if (group != null) _offer(group);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns [group], or first shows what choosing it will do.
  void _offer(AccountGroup group) {
    if (!mounted) return;
    final text = widget.consequenceOf?.call(group);
    if (text == null) {
      Navigator.of(context).pop(group);
      return;
    }
    setState(() {
      _pending = group;
      _pendingText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pending = _pending;
    if (pending != null) {
      return ListView(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(pending.label, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(_pendingText ?? ''),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(pending),
                child: Text(l10n.settings_accounts_continue),
              ),
            ],
          ),
        ],
      );
    }

    final groups = [
      for (final g in ref.watch(accountGroupsProvider).value ?? const [])
        if (_allowed(g.kind)) g,
    ];
    final presentKinds = {for (final g in groups) g.kind};
    final offers = [
      for (final o in ref.watch(offerableAccountKindsProvider))
        if (_offerAllowed(o) &&
            !(kindOfOffer(o) != null && presentKinds.contains(kindOfOffer(o))))
          o,
    ];
    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        controller: widget.controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!widget.addOnly && groups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: buildSettingsSectionHeader(
                context,
                l10n.settings_accounts_sheet_yours,
              ),
            ),
            for (final g in groups)
              AccountGroupTile(
                group: g,
                inSheet: true,
                selected: g.key == widget.currentKey,
                onTap: () => _choose(g),
              ),
          ],
          if (offers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: buildSettingsSectionHeader(
                context,
                l10n.settings_accounts_sheet_add,
              ),
            ),
            for (final o in offers)
              ListTile(
                leading: Icon(switch (kindOfOffer(o)) {
                  final kind? => accountKindIcon(kind),
                  null => accountKindIcon(AccountKind.s3),
                }),
                title: Text(_offerLabel(context, o)),
                trailing: const Icon(Icons.add),
                onTap: () => _add(o),
              ),
          ],
        ],
      ),
    );
  }
}

String _offerLabel(BuildContext context, AccountKindOffer offer) {
  final l10n = context.l10n;
  return switch (offer) {
    AccountKindOffer.icloud => l10n.settings_cloudSync_provider_icloud,
    AccountKindOffer.googleDrive =>
      l10n.settings_cloudSync_provider_googleDrive,
    AccountKindOffer.dropbox => l10n.settings_cloudSync_provider_dropbox_title,
    AccountKindOffer.ownServer => l10n.settings_accounts_ownServer_title,
  };
}
