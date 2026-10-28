import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_matcher.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_merge.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_card_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Shows a received buddy card before anything is saved (issue #3728),
/// whichever way it arrived: nearby, QR, NFC or a file.
class BuddyCardPreviewPage extends ConsumerStatefulWidget {
  const BuddyCardPreviewPage({super.key, required this.decoded});

  final BuddyCardDecoded decoded;

  @override
  ConsumerState<BuddyCardPreviewPage> createState() =>
      _BuddyCardPreviewPageState();
}

class _BuddyCardPreviewPageState extends ConsumerState<BuddyCardPreviewPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buddiesAsync = ref.watch(allBuddiesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.buddyCard_preview_title)),
      body: buddiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (buddies) =>
            _body(context, matchBuddyCard(widget.decoded.card, buddies)),
      ),
    );
  }

  Widget _body(BuildContext context, BuddyCardMatch match) {
    final l10n = context.l10n;
    final card = widget.decoded.card;
    final existing = switch (match) {
      CardRecognised(:final buddy) => buddy,
      CardPossibleMatch(:final buddy) => buddy,
      CardNew() => null,
    };
    final changes = buddyCardChanges(
      match is CardRecognised ? existing : null,
      card,
    );
    final title = switch (match) {
      CardRecognised(:final buddy) => l10n.buddyCard_preview_updateTitle(
        buddy.name,
      ),
      CardPossibleMatch() => l10n.buddyCard_preview_possibleTitle(card.name),
      CardNew() => l10n.buddyCard_preview_addTitle(card.name),
    };
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ProfileAvatar(
            photo: card.photo,
            initials: _initials(card.name),
            radius: 40,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (widget.decoded.trimmed)
          _note(context, l10n.buddyCard_preview_trimmed),
        if (widget.decoded.newerFormat)
          _note(context, l10n.buddyCard_preview_newer),
        const SizedBox(height: 12),
        if (changes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.buddyCard_preview_noChanges,
              textAlign: TextAlign.center,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final change in changes)
                  ListTile(
                    title: Text(_fieldLabel(l10n, change.field)),
                    subtitle: Text(_changeText(l10n, change)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ..._actions(context, match, existing),
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  List<Widget> _actions(
    BuildContext context,
    BuddyCardMatch match,
    Buddy? existing,
  ) {
    final l10n = context.l10n;
    final buttons = <Widget>[
      if (match is CardRecognised)
        FilledButton(
          onPressed: _saving ? null : () => _update(existing!),
          child: Text(l10n.buddyCard_action_update),
        ),
      if (match is CardPossibleMatch) ...[
        FilledButton(
          onPressed: _saving ? null : () => _update(existing!),
          child: Text(l10n.buddyCard_preview_updateTitle(existing!.name)),
        ),
        OutlinedButton(
          onPressed: _saving ? null : _addNew,
          child: Text(l10n.buddyCard_action_addAsNew),
        ),
      ],
      if (match is CardNew)
        FilledButton(
          onPressed: _saving ? null : _addNew,
          child: Text(l10n.buddyCard_action_add),
        ),
      TextButton(
        onPressed: _saving ? null : _discard,
        child: Text(l10n.buddyCard_action_discard),
      ),
    ];
    return [
      for (final b in buttons)
        Padding(padding: const EdgeInsets.only(top: 8), child: b),
    ];
  }

  String _fieldLabel(AppLocalizations l10n, BuddyCardChangeField field) =>
      switch (field) {
        BuddyCardChangeField.name => l10n.buddyCard_field_name,
        BuddyCardChangeField.phone => l10n.buddyCard_field_phone,
        BuddyCardChangeField.email => l10n.buddyCard_field_email,
        BuddyCardChangeField.social => l10n.buddyCard_field_social,
        BuddyCardChangeField.dives => l10n.buddyCard_field_dives,
        BuddyCardChangeField.divingSince => l10n.buddyCard_field_divingSince,
        BuddyCardChangeField.lastDive => l10n.buddyCard_field_lastDive,
        BuddyCardChangeField.certifications =>
          l10n.buddyCard_field_certifications,
      };

  String _changeText(AppLocalizations l10n, BuddyCardChange change) {
    String show(String value) => change.field == BuddyCardChangeField.lastDive
        ? UnitFormatter(
            ref.read(settingsProvider),
          ).formatDate(DateTime.parse(value))
        : value;
    final to = show(change.to);
    final from = change.from;
    return from == null ? to : l10n.buddyCard_preview_changed(show(from), to);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase());
    return letters.join();
  }

  Future<void> _addNew() async {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    await _save(
      () => ref
          .read(buddyCardImporterProvider)
          .addNew(widget.decoded.card, diverId: diverId),
      added: true,
    );
  }

  Future<void> _update(Buddy existing) => _save(
    () => ref
        .read(buddyCardImporterProvider)
        .update(existing, widget.decoded.card),
    added: false,
  );

  Future<void> _save(
    Future<Buddy> Function() write, {
    required bool added,
  }) async {
    setState(() => _saving = true);
    try {
      final buddy = await write();
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            added
                ? l10n.buddyCard_saved_added(buddy.name)
                : l10n.buddyCard_saved_updated(buddy.name),
          ),
        ),
      );
      context.go('/buddies/${buddy.id}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _discard() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/buddies');
    }
  }
}
