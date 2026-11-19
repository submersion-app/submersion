part of 'buddy_merge_page.dart';

/// The merge itself: the survivor as the form has it, checked, confirmed,
/// then merged.
extension _BuddyMergeSave on _BuddyMergeFormState {
  /// Asks whether to leave and lose what was chosen here.
  Future<bool> _discardChanges() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.buddies_dialog_discardTitle),
        content: Text(context.l10n.buddies_dialog_discardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.buddies_dialog_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.buddies_dialog_discard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<bool> _confirmMerge() async {
    final count = widget.buddies.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.buddies_edit_merge_confirmTitle),
        content: Text(context.l10n.buddies_edit_merge_confirmBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.buddies_edit_merge_title),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String? _orNone(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// The survivor as merged here.
  Buddy _merged(String? diverId, String? linkedDiverId) {
    final now = DateTime.now();
    final card = _cardSource;
    return Buddy(
      id: '',
      diverId: diverId,
      linkedDiverId: linkedDiverId,
      name: _nameController.text.trim(),
      email: _orNone(_emailController),
      phone: _orNone(_phoneController),
      photoPath: _merge.mergedPhotoPath,
      photo: _merge.mergedPhoto,
      notes: _notesController.text.trim(),
      // The merge has no favourite control: the survivor keeps its own.
      isFavorite: _survivor.isFavorite,
      excludedFromRankings: _excludedFromRankings,
      createdAt: _survivor.createdAt,
      updatedAt: now,
      // The buddy card figures (issue #3728) have no field: only a card
      // writes them, so the merge keeps them as they were.
      cardId: card?.cardId,
      socialHandle: _orNone(_socialController),
      country: BuddyCountryColumns.text(_countryController.text),
      countryCode: countryCodeOnSave(
        country: _countryController.text,
        known: (country: _survivor.country, code: _survivor.countryCode),
      ),
      cardDiveCount: card?.cardDiveCount,
      cardDivingSince: card?.cardDivingSince,
      cardLastDive: card?.cardLastDive,
      cardReceivedAt: card?.cardReceivedAt,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final links = ref.read(buddyProfileLinkRepositoryProvider);
    final notifier = ref.read(buddyListNotifierProvider.notifier);
    _setSaving(true);
    try {
      final diverId =
          _survivor.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);
      // The profile link the survivor keeps is checked before anything is
      // written: at most one buddy per owner list may be a given profile,
      // and never the owner itself (issue #2002).
      final linkedDiverId = _merge.mergedLinkedDiverId;
      if (linkedDiverId != null) {
        try {
          await links.assertLinkAllowed(
            ownerDiverId: diverId,
            linkedDiverId: linkedDiverId,
            // The link is held by one of the buddies being merged: not
            // taken by another.
            buddyId: widget.buddies
                .where((b) => b.linkedDiverId == linkedDiverId)
                .firstOrNull
                ?.id,
          );
        } on BuddyLinkRefused catch (refusal) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(switch (refusal.reason) {
                BuddyLinkRefusal.self => l10n.buddies_linkedProfile_refusedSelf,
                BuddyLinkRefusal.taken =>
                  l10n.buddies_linkedProfile_refusedTaken(
                    refusal.existingBuddy?.name ?? '',
                  ),
              }),
              persist: false,
            ),
          );
          _setSaving(false);
          return;
        }
      }
      final buddy = _merged(diverId, linkedDiverId);
      if (!mounted) return;
      if (!await _confirmMerge()) {
        if (mounted) _setSaving(false);
        return;
      }
      final buddyIds = [for (final b in widget.buddies) b.id];
      final snapshot = await notifier.mergeBuddies(buddy, buddyIds);
      if (mounted) {
        Navigator.of(
          context,
        ).pop(BuddyMergeResult(survivorId: buddyIds.first, snapshot: snapshot));
      }
    } catch (e) {
      if (!mounted) return;
      final message =
          e is StateError && e.message.contains('different profiles')
          ? l10n.buddies_merge_refusedDifferentLinks
          : l10n.buddies_message_errorSaving(e.toString());
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: errorColor),
      );
      _setSaving(false);
    }
  }
}
