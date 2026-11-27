part of 'species_detail_page.dart';

/// The species page's use of the shared editing host (issue #4527, phase
/// 3): what is its own about saving, reading back and its cards.
mixin _SpeciesDetailPageEditing
    on
        ConsumerState<SpeciesDetailPage>,
        RecordEditHost<SpeciesDetailPage, Species>,
        RecordOpenUnlocked<SpeciesDetailPage, Species> {
  @override
  String get hostRecordId => widget.speciesId;

  @override
  String recordIdOf(Species record) => record.id;

  @override
  bool openUnlockedOf(SpeciesDetailPage widget) => widget.openUnlocked;

  /// The species page is never a pane: nothing waits for its sitting's end.
  @override
  VoidCallback? get onOpenedSittingEnded => null;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<Species>> get hostEditCards => speciesEditCards.values;

  @override
  Species? get storedForUnlock =>
      ref.read(speciesProvider(widget.speciesId)).value;

  @override
  String editingTitle(Species record) => context.l10n.recordEdit_editingTitle(
    record.localizedCommonName(context.l10n),
  );

  /// Writes the sitting through the species' save service: its changed
  /// values and its held writes (photos tagged and added), in one
  /// transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<Species> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(speciesEditSaveServiceProvider);
    final enqueue = ref.read(mediaStoreEnqueueProvider);
    final result = await service.save(
      // The species the sitting was opened on, whatever the page shows by
      // the time the write is asked for.
      speciesId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
    // The photos the sitting added go to the media store once committed,
    // each on its own: a failure there is not a failed save.
    for (final mediaId in speciesImportsWritten(session)) {
      try {
        enqueue(mediaId);
      } catch (_) {
        // The store retries from its own queue.
      }
    }
  }

  @override
  Future<Species?> rereadStored(ProviderContainer container, Species stored) {
    container.invalidate(speciesProvider(stored.id));
    return container.read(speciesProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty: Description.
  @override
  List<AddStripEntry> addStripEntries(Species working) {
    final controller = maybeEditController;
    final session = controller?.session;
    if (controller == null || session == null) return const [];
    final card = speciesEditCards[SpeciesCardId.description]!;
    if (!card.isEmpty(working) || _showsWhileEmpty(SpeciesCardId.description)) {
      return const [];
    }
    return [
      AddStripEntry(
        cardId: card.id,
        label: card.title(context),
        changed: session.changedCardIds.contains(card.id),
      ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(SpeciesCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(SpeciesCardId id, Widget child) =>
      RecordCardFrame<Species>(card: speciesEditCards[id]!, child: child);

  /// [child], a section the page calculates, faded and labelled
  /// "Calculated" while unlocked.
  Widget _calculated(Widget child) => RecordCardFade<Species>(
    reason: RecordCardFadeReason.calculated,
    child: child,
  );

  /// The Photos card: locked it offers nothing that writes; unlocked its Tag
  /// photos holds the choice for Save, and the photos held show ahead of the
  /// stored ones, each with a way to take it back.
  Widget _photosInSitting() {
    final session = maybeEditController?.session;
    final held = session == null
        ? const <MediaItem>[]
        : [
            for (final p in heldSpeciesImports(session)) p.item,
            ...heldSpeciesTags(session),
          ];
    final added = session == null
        ? const <String>{}
        : {for (final p in heldSpeciesImports(session)) p.item.id};
    final l10n = context.l10n;
    return SpeciesPhotosSection(
      speciesId: widget.speciesId,
      onTagPhotos: session == null ? null : () => _tagInSitting(session),
      onAddPhotos: session == null ? null : () => _addInSitting(session),
      changedMark:
          session != null &&
              session.changedCardIds.contains(SpeciesCardId.photos.name)
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: RecordChangedDot(),
            )
          : null,
      pendingItems: held,
      pendingOverlay: (item) => Align(
        alignment: AlignmentDirectional.topEnd,
        child: IconButton.filledTonal(
          key: ValueKey('species_pending_remove_${item.id}'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 16),
          tooltip: l10n.forms_cancel,
          onPressed: session == null
              ? null
              : () => added.contains(item.id)
                    ? releaseSpeciesImport(session, item.id)
                    : releaseSpeciesTag(session, item.id),
        ),
      ),
    );
  }

  /// Opens the picker and the review to choose photos to add, and holds
  /// them, prepared, in [session] to be written and tagged at Save.
  Future<void> _addInSitting(EditSession<Species> session) async {
    final launch = ref.read(speciesPhotoPrepareLauncherProvider);
    final write = ref.read(speciesImportWriterProvider);
    final tagging = ref.read(speciesTaggingServiceProvider);
    final prepared = await launch(context, ref, widget.speciesId);
    if (prepared == null || prepared.isEmpty) return;
    holdSpeciesImports(session, prepared, write: write, tagging: tagging);
  }

  /// Opens the tag picker to choose photos, and holds the choice in
  /// [session] to be tagged at Save.
  Future<void> _tagInSitting(EditSession<Species> session) async {
    final tagging = ref.read(speciesTaggingServiceProvider);
    final choice = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SpeciesTagPickerPage(
          speciesId: widget.speciesId,
          alreadyChosen: {for (final m in heldSpeciesTags(session)) m.id},
        ),
      ),
    );
    if (choice is! SpeciesTagChoice || choice.items.isEmpty) return;
    holdSpeciesTags(session, choice.items, tagging);
  }

  /// Whether the record's operations may run now, or why not.
  RecordOperationBlock? get _speciesOperationBlock =>
      recordOperationBlockOf(editController);

  /// The menu's whole-record operations for [species]: Delete for a custom
  /// species, under the caption that says why it is unavailable.
  List<PopupMenuEntry<String>> _speciesRecordMenuItems(Species species) {
    if (species.isBuiltIn) return const [];
    final l10n = context.l10n;
    final block = _speciesOperationBlock;
    final reason = recordOperationReason(l10n, block, plural: true);
    return [
      if (reason != null) recordOperationCaption<String>(context, reason),
      PopupMenuItem<String>(
        value: 'delete',
        enabled: block == null || block == RecordOperationBlock.none,
        child: Text(l10n.marineLife_speciesManage_deleteButton),
      ),
    ];
  }

  /// Runs [operation] through the sitting, as every whole-record operation
  /// does.
  Future<void> _runSpeciesOperation(Future<bool> Function() operation) =>
      recordOperationRunnerOf(
        editController,
        record: 'species ${widget.speciesId}',
      )(operation);

  /// Deletes [species] as the manage page does: refused while in use, else
  /// after the same confirmation. Answers whether it wrote.
  Future<bool> _deleteSpecies(Species species) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(speciesRepositoryProvider);
    final name = species.localizedCommonName(l10n);
    if (await repository.isSpeciesInUse(species.id)) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.marineLife_species_delete_inUseError(name)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.marineLife_species_delete_confirmTitle),
        content: Text(l10n.marineLife_species_delete_confirmBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.marineLife_speciesManage_cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.marineLife_speciesManage_deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await repository.deleteSpecies(species.id);
    } catch (error) {
      // Come into use since the check, or a failed write: say so, as the
      // manage page does.
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.marineLife_species_delete_error('$error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.marineLife_species_delete_snackbar(name))),
    );
    // The species has gone: back where the diver came from, else to the
    // species list.
    if (mounted) {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.canPop() ? router.pop() : router.go('/species');
      }
    }
    return true;
  }
}
