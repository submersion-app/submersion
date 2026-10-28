import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/data/services/buddy_card_builder.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What goes on the diver's buddy card (issue #3728). Only fields the diver
/// has something for are listed; the name is always sent, and medical,
/// insurance and emergency details are never offered.
class ShareChoicesSheet extends StatefulWidget {
  const ShareChoicesSheet({
    super.key,
    required this.initial,
    required this.available,
    required this.onChanged,
  });

  final BuddyCardShareChoices initial;
  final Set<BuddyCardField> available;
  final ValueChanged<BuddyCardShareChoices> onChanged;

  @override
  State<ShareChoicesSheet> createState() => _ShareChoicesSheetState();
}

class _ShareChoicesSheetState extends State<ShareChoicesSheet> {
  late BuddyCardShareChoices _choices = widget.initial;

  static bool _isOn(BuddyCardShareChoices c, BuddyCardField f) => switch (f) {
    BuddyCardField.photo => c.photo,
    BuddyCardField.phone => c.phone,
    BuddyCardField.email => c.email,
    BuddyCardField.certifications => c.certifications,
    BuddyCardField.cardDetails => c.cardDetails,
    BuddyCardField.diveCount => c.diveCount,
    BuddyCardField.divingSince => c.divingSince,
    BuddyCardField.lastDive => c.lastDive,
    BuddyCardField.social => c.social,
  };

  static BuddyCardShareChoices _set(
    BuddyCardShareChoices c,
    BuddyCardField f,
    bool on,
  ) => switch (f) {
    BuddyCardField.photo => c.copyWith(photo: on),
    BuddyCardField.phone => c.copyWith(phone: on),
    BuddyCardField.email => c.copyWith(email: on),
    BuddyCardField.certifications => c.copyWith(certifications: on),
    BuddyCardField.cardDetails => c.copyWith(cardDetails: on),
    BuddyCardField.diveCount => c.copyWith(diveCount: on),
    BuddyCardField.divingSince => c.copyWith(divingSince: on),
    BuddyCardField.lastDive => c.copyWith(lastDive: on),
    BuddyCardField.social => c.copyWith(social: on),
  };

  static String _label(AppLocalizations l10n, BuddyCardField f) => switch (f) {
    BuddyCardField.photo => l10n.buddyShare_photo,
    BuddyCardField.phone => l10n.buddyShare_phone,
    BuddyCardField.email => l10n.buddyShare_email,
    BuddyCardField.certifications => l10n.buddyShare_certifications,
    BuddyCardField.cardDetails => l10n.buddyShare_cardDetails,
    BuddyCardField.diveCount => l10n.buddyShare_diveCount,
    BuddyCardField.divingSince => l10n.buddyShare_divingSince,
    BuddyCardField.lastDive => l10n.buddyShare_lastDive,
    BuddyCardField.social => l10n.buddyShare_social,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.buddyShare_title,
              style: theme.textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: Text(l10n.buddyShare_name),
            subtitle: Text(l10n.buddyShare_alwaysShared),
          ),
          for (final field in BuddyCardField.values)
            if (widget.available.contains(field))
              SwitchListTile(
                title: Text(_label(l10n, field)),
                value: _isOn(_choices, field),
                // Card numbers and dates travel only with the
                // certifications they belong to.
                onChanged:
                    field == BuddyCardField.cardDetails &&
                        !_choices.certifications
                    ? null
                    : (on) {
                        setState(() => _choices = _set(_choices, field, on));
                        widget.onChanged(_choices);
                      },
              ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.buddyShare_neverShared,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
