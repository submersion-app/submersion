import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver picked in an account chooser.
sealed class AccountSheetChoice {
  const AccountSheetChoice();
}

final class ChoseAccount extends AccountSheetChoice {
  const ChoseAccount(this.group);
  final AccountGroup group;
}

final class ChoseNone extends AccountSheetChoice {
  const ChoseNone();
}

/// The account picker's body (spec section 7.4): the diver's accounts, then
/// the kinds that can be added here. It reports the choice, an account
/// signed in on this device, through [onChosen]. The account sheet shows it
/// in a bottom sheet; Set up this device shows it inline ([embedded]).
///
/// [allowedKinds] restricts both sections (shared libraries allow only S3
/// and WebDAV). When [consequenceOf] returns text for the choice, the
/// chooser shows it with Cancel and Continue first, so a choice with
/// consequences is explained before it takes effect. [webdavCheck] is how an
/// own WebDAV server added or signed in here is checked (a library reaches
/// its folder read only).
class AccountChooser extends ConsumerStatefulWidget {
  const AccountChooser({
    super.key,
    required this.onChosen,
    this.onCancel,
    this.controller,
    this.allowedKinds,
    this.currentKey,
    this.addOnly = false,
    this.consequenceOf,
    this.webdavCheck,
    this.noneLabel,
    this.noneSelected = false,
    this.offerHints = false,
    this.signedInFirst = false,
    this.embedded = false,
  });

  final ValueChanged<AccountSheetChoice> onChosen;

  /// Cancel on an explained choice; without it, the chooser returns to its
  /// list.
  final VoidCallback? onCancel;

  final ScrollController? controller;
  final Set<AccountKind>? allowedKinds;
  final String? currentKey;
  final bool addOnly;
  final String? Function(AccountGroup choice)? consequenceOf;
  final WebDavCheck? webdavCheck;

  /// A first choice of no account (the Backups copy's "No copy off this
  /// device", spec section 12), shown as selected when [noneSelected].
  final String? noneLabel;
  final bool noneSelected;

  /// Says under each kind what adding it takes (spec 6.4, step 1).
  final bool offerHints;

  /// Lists the accounts signed in on this device before the others.
  final bool signedInFirst;

  /// Part of a scrolling page rather than a sheet of its own.
  final bool embedded;

  @override
  ConsumerState<AccountChooser> createState() => _AccountChooserState();
}

class _AccountChooserState extends ConsumerState<AccountChooser> {
  AccountGroup? _pending;
  String? _pendingText;
  bool _busy = false;

  /// The accounts the chooser lists. Without Google among the kinds (the
  /// library pages' own servers) only those kinds are probed; otherwise it
  /// shares the full list the page already holds.
  FutureProvider<List<AccountGroup>> get _groupsProvider {
    final kinds = widget.allowedKinds;
    return kinds == null || kinds.contains(AccountKind.googledrive)
        ? accountGroupsProvider
        : accountGroupsOfKindsProvider(accountKindsKey(kinds));
  }

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
        if (!await signInToGroup(
          context,
          ref,
          group,
          webdavCheck: widget.webdavCheck,
        )) {
          return;
        }
        // By a row, not the key: a row nothing could place before the
        // sign-in is grouped by its server after it.
        final fresh = await ref.read(_groupsProvider.future);
        chosen = fresh.holding(group.rows.first.id) ?? group;
      }
      _offer(chosen);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(AccountKindOffer offer) async {
    setState(() => _busy = true);
    try {
      final row = await addAccountRow(
        context,
        ref,
        offer,
        kinds: _serverKinds,
        webdavCheck: widget.webdavCheck,
      );
      if (row == null) return;
      final groups = await ref.read(_groupsProvider.future);
      final group = groups.holding(row.id);
      if (group != null) _offer(group);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reports [group], or first shows what choosing it will do.
  void _offer(AccountGroup group) {
    if (!mounted) return;
    final text = widget.consequenceOf?.call(group);
    if (text == null) {
      widget.onChosen(ChoseAccount(group));
      return;
    }
    setState(() {
      _pending = group;
      _pendingText = text;
    });
  }

  void _cancelPending() {
    final cancel = widget.onCancel;
    if (cancel != null) {
      cancel();
    } else {
      setState(() => _pending = _pendingText = null);
    }
  }

  ListView _list({
    required EdgeInsets padding,
    required List<Widget> children,
  }) => widget.embedded
      ? ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          children: children,
        )
      : ListView(
          controller: widget.controller,
          padding: padding,
          children: children,
        );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pending = _pending;
    if (pending != null) {
      return _list(
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
                onPressed: _cancelPending,
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => widget.onChosen(ChoseAccount(pending)),
                child: Text(l10n.settings_accounts_continue),
              ),
            ],
          ),
        ],
      );
    }

    // Never an empty list while the accounts load (or failed to): it would
    // hide the diver's accounts and offer to add ones that exist.
    final groupsAsync = ref.watch(_groupsProvider);
    if (!groupsAsync.hasValue) {
      return Center(
        child: groupsAsync.hasError
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.settings_connectedAccounts_loadError),
              )
            : const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
      );
    }
    final allowed = [
      for (final g in groupsAsync.requireValue)
        if (_allowed(g.kind)) g,
    ];
    final groups = widget.signedInFirst
        ? [
            ...allowed.where((g) => g.signedInHere),
            ...allowed.where((g) => !g.signedInHere),
          ]
        : allowed;
    final presentKinds = {for (final g in groups) g.kind};
    // A kind with one account per library (Dropbox, Google) is offered
    // only until it is added; a Git repository, like an own server, can be
    // added again.
    bool alreadyAdded(AccountKindOffer o) => switch (kindOfOffer(o)) {
      final kind? =>
        naturalKeyForKind(kind) != null && presentKinds.contains(kind),
      null => false,
    };
    final offers = [
      for (final o in ref.watch(offerableAccountKindsProvider))
        if (_offerAllowed(o) && !alreadyAdded(o)) o,
    ];
    final noneLabel = widget.noneLabel;
    // Not closed while a sign-in or switch runs: what follows it needs this
    // chooser's context and ref.
    return PopScope(
      canPop: !_busy,
      child: AbsorbPointer(
        absorbing: _busy,
        child: _list(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (!widget.addOnly &&
                (groups.isNotEmpty || noneLabel != null)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: buildSettingsSectionHeader(
                  context,
                  l10n.settings_accounts_sheet_yours,
                ),
              ),
              if (noneLabel != null)
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: Text(noneLabel),
                  selected: widget.noneSelected,
                  trailing: widget.noneSelected
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => widget.onChosen(const ChoseNone()),
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
                  subtitle: switch (_offerHint(context, o)) {
                    final hint? => Text(hint),
                    null => null,
                  },
                  trailing: const Icon(Icons.add),
                  onTap: () => _add(o),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String? _offerHint(BuildContext context, AccountKindOffer offer) {
    final l10n = context.l10n;
    if (offer == AccountKindOffer.git) {
      return l10n.settings_cloudSync_provider_git_subtitle;
    }
    if (!widget.offerHints) return null;
    return switch (offer) {
      AccountKindOffer.icloud => l10n.settings_setUpDevice_offer_icloud,
      AccountKindOffer.googleDrive =>
        l10n.settings_setUpDevice_offer_googleDrive,
      AccountKindOffer.dropbox => l10n.settings_setUpDevice_offer_dropbox,
      AccountKindOffer.ownServer => l10n.settings_setUpDevice_offer_ownServer,
      AccountKindOffer.git => null,
    };
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
    AccountKindOffer.git => l10n.settings_cloudSync_provider_git_title,
  };
}
