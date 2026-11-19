import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_country_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_profile_link_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_country_field.dart';
import 'package:submersion/features/buddies/presentation/widgets/linked_profile_field.dart';
import 'package:submersion/features/buddies/presentation/widgets/linked_profile_suggestion.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The buddy Contact card's editor (issue #4527, phase 3): email, phone,
/// social handle, country and the local profile the buddy is, as the edit
/// form has them.
///
/// A profile picked is checked at once: one another buddy holds, or the
/// diver themselves, is refused under the field with today's message and
/// not set. The save checks it again, since another device may link it
/// meanwhile.
class BuddyContactCardEditor extends ConsumerStatefulWidget {
  const BuddyContactCardEditor({super.key, required this.session});

  final EditSession<Buddy> session;

  @override
  ConsumerState<BuddyContactCardEditor> createState() =>
      _BuddyContactCardEditorState();
}

class _BuddyContactCardEditorState
    extends ConsumerState<BuddyContactCardEditor> {
  EditSession<Buddy> get _session => widget.session;

  late final _email = _bind(buddyEmailField);
  late final _phone = _bind(buddyPhoneField);
  late final _social = _bind(buddySocialHandleField);
  late final _country = _bind(buddyCountryField);

  /// Why the last profile picked was refused, or null.
  String Function(AppLocalizations l10n)? _refused;

  /// "Not now" on the suggestion hides it for this sitting's card.
  bool _suggestionDismissed = false;

  /// Counts the picks, so a check that answers after a later pick (or a
  /// clear) is dropped.
  int _picks = 0;

  FieldTextBinding<Buddy, String?> _bind(EditField<Buddy, String?> field) =>
      FieldTextBinding<Buddy, String?>(
        session: _session,
        field: field,
        format: (v) => v ?? '',
        parse: FieldValue<String?>.new,
      );

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _social.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _pickProfile(String? id) async {
    final pick = ++_picks;
    if (id == null) {
      setState(() => _refused = null);
      _session.set(buddyLinkedDiverField, null);
      return;
    }
    final links = ref.read(buddyProfileLinkRepositoryProvider);
    final buddy = _session.working;
    try {
      await links.assertLinkAllowed(
        ownerDiverId: buddy.diverId,
        linkedDiverId: id,
        buddyId: buddy.id,
      );
    } on BuddyLinkRefused catch (refusal) {
      if (!mounted || pick != _picks) return;
      setState(
        () => _refused = (l10n) => switch (refusal.reason) {
          BuddyLinkRefusal.self => l10n.buddies_linkedProfile_refusedSelf,
          BuddyLinkRefusal.taken => l10n.buddies_linkedProfile_refusedTaken(
            refusal.existingBuddy?.name ?? '',
          ),
        },
      );
      return;
    } catch (_) {
      // The check could not be made: the link is not set, and the field
      // says to try again.
      if (!mounted || pick != _picks) return;
      setState(() => _refused = (l10n) => l10n.common_error_tryAgain);
      return;
    }
    if (!mounted || _session.isDisposed || pick != _picks) return;
    setState(() => _refused = null);
    _session.set(buddyLinkedDiverField, id);
  }

  Widget _suggestion(Buddy buddy) {
    final email = buddy.email?.trim() ?? '';
    final diver = ref
        .watch(
          linkedProfileSuggestionProvider((
            ownerDiverId: buddy.diverId,
            name: buddy.name,
            email: email.isEmpty ? null : email,
          )),
        )
        .value;
    if (diver == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LinkedProfileSuggestion(
        diver: diver,
        onLink: () => _pickProfile(diver.id),
        onDismiss: () => setState(() => _suggestionDismissed = true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final working = _session.working;
        final refused = _refused;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('buddy-edit-email'),
              controller: _email.controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.buddies_field_email,
                prefixIcon: const Icon(Icons.email),
                hintText: l10n.buddies_field_emailHint,
                errorText: buddyEmailValid(_email.controller.text)
                    ? null
                    : l10n.buddies_validation_emailInvalid,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('buddy-edit-phone'),
              controller: _phone.controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.buddies_field_phone,
                prefixIcon: const Icon(Icons.phone),
                hintText: l10n.buddies_field_phoneHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('buddy-edit-social'),
              controller: _social.controller,
              decoration: InputDecoration(
                labelText: l10n.buddyShare_social,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 16),
            BuddyCountryField(
              controller: _country.controller,
              suggestions:
                  ref.watch(buddyCountrySuggestionsProvider).value ?? const [],
              decoration: InputDecoration(
                labelText: l10n.buddies_field_country,
                prefixIcon: const Icon(Icons.public),
                hintText: l10n.buddies_field_countryHint,
              ),
            ),
            const SizedBox(height: 24),
            if (!_suggestionDismissed && working.linkedDiverId == null)
              _suggestion(working),
            LinkedProfileField(
              ownerDiverId: working.diverId,
              linkedDiverId: working.linkedDiverId,
              onChanged: _pickProfile,
            ),
            if (refused != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
                child: Text(
                  refused(l10n),
                  key: const ValueKey('buddy-edit-link-refused'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
