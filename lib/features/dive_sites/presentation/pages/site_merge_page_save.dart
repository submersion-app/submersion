part of 'site_merge_page.dart';

/// The merge page's save: the confirmation, the merge, the expected
/// species written on the survivor, and the pop with its result.
mixin _SiteMergeSave on _SiteMergeCandidates, _SiteMergeLocation {
  Future<bool> _confirmMerge() async {
    final count = _mergedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveSites_edit_merge_confirmTitle),
        content: Text(context.l10n.diveSites_edit_merge_confirmBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.diveSites_edit_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.diveSites_edit_appBar_merge),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// The survivor as the fields show it, with the survivor's id and
  /// sharing, owned by [diverId].
  DiveSite _mergedSite(DiveSite survivor, String? diverId) {
    final units = ref.read(unitFormatterProvider);
    String? trimmed(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    // validate() already stopped a position out of range.
    final location = _parsedCoordinates();

    // Blank is "not recorded"; validate() already stopped unreadable text.
    final minDepth = _SiteMergeFields._validatedNumber(_minDepthController);
    final maxDepth = _SiteMergeFields._validatedNumber(_maxDepthController);
    final altitude = _SiteMergeFields._validatedNumber(_altitudeController);
    // Location fields persist exactly as shown: an empty field is never
    // refilled from the coordinates on save.
    final country = trimmed(_countryController);
    return DiveSite(
      id: survivor.id,
      diverId: diverId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      country: country,
      countryCode: countryCodeOnSave(
        country: country,
        known: _knownCountryCode,
      ),
      region: trimmed(_regionController),
      city: trimmed(_cityController),
      island: trimmed(_islandController),
      bodyOfWater: trimmed(_bodyOfWaterController),
      minDepth: minDepth == null ? null : units.depthToMeters(minDepth),
      maxDepth: maxDepth == null ? null : units.depthToMeters(maxDepth),
      difficulty: _difficulty,
      location: location,
      rating: _rating > 0 ? _rating : null,
      notes: _notesController.text.trim(),
      hazards: trimmed(_hazardsController),
      accessNotes: trimmed(_accessNotesController),
      mooringNumber: trimmed(_mooringNumberController),
      parkingInfo: trimmed(_parkingInfoController),
      altitude: altitude == null ? null : units.altitudeToMeters(altitude),
      waterType: _waterType,
      entryMethods: _entryMethods,
      exitMethods: _exitMethods,
      isShared: survivor.isShared,
    );
  }

  Future<void> _saveMerge() async {
    final survivor = _survivor;
    if (survivor == null || !_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(siteListNotifierProvider.notifier);
    void say(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(message)));

    setState(() => _isLoading = true);
    try {
      final actingDiverId = await ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      if (!mounted) return;
      // The merged site's owner: the survivor's, or the active profile for
      // an unowned one. The merge keeps what it allows.
      final site = _mergedSite(survivor, survivor.diverId ?? actingDiverId);
      // A shared site library not connected on this device: nothing here
      // could reach it (issue #2567).
      final libraryId = survivor.sharedLibraryId;
      if (libraryId != null &&
          await libraryRoleNow(ref.read, libraryId) == null) {
        if (mounted) say(l10n.sharedLibrary_list_notConnected);
        return;
      }
      // A survivor this profile may not edit (a library site it only
      // reads) is refused, never sent as a suggestion (plan 7, Question 3),
      // and before the confirmation, whose answer could not change that.
      final mayEdit = await LibraryEditStamper().mayEdit(
        survivor.id,
        actingDiverId: actingDiverId,
      );
      if (!mounted) return;
      if (!mayEdit) {
        say(l10n.sharedItems_notOwner_site);
        return;
      }
      if (!await _confirmMerge() || !mounted) return;

      final snapshot = await notifier.mergeSites(site, _mergedIds);
      if (!mounted) return;
      if (snapshot == null) {
        // Refused (a site belongs to another profile, issue #2594): nothing
        // merged, so stay, say so and write nothing more.
        say(l10n.sharedItems_notOwner_site);
        return;
      }

      // The merge writes the types, tags and species' union itself; the
      // expected species are then the ones the page shows. The merge is done
      // by now, so a failed write here still hands the list the merge (and
      // its Undo) rather than keeping the page on sites already merged.
      final survivorId = survivor.id;
      try {
        await ref
            .read(siteExpectedSpeciesNotifierProvider(survivorId).notifier)
            .setSpecies([for (final s in _expectedSpecies) s.id]);
      } catch (e, stackTrace) {
        _mergeLog.error(
          'Could not write the expected species of merged site $survivorId',
          error: e,
          stackTrace: stackTrace,
        );
      }
      if (!mounted) return;
      ref
        ..invalidate(siteExpectedSpeciesProvider(survivorId))
        ..invalidate(siteSpottedSpeciesProvider(survivorId))
        ..invalidate(siteTypesForSiteProvider(survivorId))
        ..invalidate(tagsForSiteProvider(survivorId))
        ..invalidate(sitesWithCountsProvider)
        ..invalidate(sitesProvider);
      for (final id in widget.siteIds) {
        ref.invalidate(siteProvider(id));
      }
      _hasChanges = false;
      context.pop(SiteMergeResult(survivorId: survivorId, snapshot: snapshot));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.diveSites_edit_snackbar_errorSaving('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
