part of 'dive_detail_page.dart';

/// What the dive detail page does on the diver's behalf. These take dialogs and
/// imports to finish, so they run on the page, which is there to report the
/// result whatever happens to the section that started one.
mixin _DiveDetailPageActions on ConsumerState<DiveDetailPage> {
  /// A promotion of a planned dive is in flight (issue #2002), so a second
  /// tap on the banner or the menu item is ignored rather than calling
  /// convertPlanToActualDive on a dive that is no longer planned.
  bool _promoting = false;

  String get diveId => widget.diveId;

  /// Re-reads everything that shows [id]'s samples and sources.
  ///
  /// Takes the container rather than using ref: the actions that call this
  /// finish after a wait the diver can leave during, and the dive list still
  /// reads the same dive once this State is gone.
  void _refreshDive(ProviderContainer container, String id) {
    container.invalidate(diveProvider(id));
    container.invalidate(diveProfileProvider(id));
    container.invalidate(sourceProfilesProvider(id));
    container.invalidate(diveDataSourcesProvider(id));
  }

  Future<void> _addPhotos(Dive dive) async {
    await PhotoImportHelper.importPhotosForDive(
      context: context,
      ref: ref,
      dive: dive,
    );
  }

  Future<void> _linkPreDiveChecklist(Dive dive) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = context.l10n.preDive_link_linked;
    final failureMessage = context.l10n.common_error_tryAgain;
    final repository = ref.read(preDiveSessionRepositoryProvider);
    final sessionId = await showLinkSessionPicker(
      context,
      diverId: dive.diverId,
    );
    if (sessionId == null) return;
    try {
      await repository.linkToDive(sessionId, dive.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return;
    }
    // Nothing on this page renders the link, so the snackbar is the only
    // evidence the write happened.
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }

  Future<void> _unlinkPreDiveChecklist(PreDiveSession linked) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = context.l10n.preDive_link_unlinked;
    final failureMessage = context.l10n.common_error_tryAgain;
    try {
      await ref
          .read(preDiveSessionRepositoryProvider)
          .unlinkFromDive(linked.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }

  /// Log this dive into a linked buddy's profile from the overflow menu.
  Future<void> _logForBuddy(Dive dive) async {
    // The dialog and the mirror transaction both take time, and the diver
    // can leave in between. Everything after the first await goes through
    // the container, which outlives this State, rather than through ref.
    final container = ProviderScope.containerOf(context, listen: false);
    final candidates = await ref.read(mirrorCandidatesProvider(dive.id).future);
    if (!mounted || candidates.isEmpty) return;
    final chosenIds = await showMirrorDiveDialog(
      context,
      candidates: candidates,
    );
    if (chosenIds == null || chosenIds.isEmpty || !mounted) return;
    await runDiveMirror(
      context: context,
      container: container,
      sourceDiveId: dive.id,
      chosen: [
        for (final c in candidates)
          if (chosenIds.contains(c.diver.id)) c,
      ],
    );
    container.invalidate(mirrorCandidatesProvider(dive.id));
    container.invalidate(siblingDivesProvider(dive.id));
  }

  /// Open a new plan that follows this dive (issue #3565): a series whose
  /// first dive starts from where this one left off.
  ///
  /// The dive is read before the plan being edited is replaced, so a failed
  /// load, or leaving the page during it, leaves that plan alone.
  Future<void> _planRepetitiveDive(Dive dive) async {
    if (!await _confirmReplacingPlan()) return;
    await ref.container.awaitFuture(seriesFollowProvider(dive.id).future);
    if (!mounted) return;
    ref.read(divePlanNotifierProvider.notifier).newPlan();
    await followLoggedDive(ref, dive.id);
    if (!mounted) return;
    openDivePlanner(context);
  }

  /// Whether a series with unsaved changes may go, saved or discarded.
  Future<bool> _confirmReplacingSeries() async {
    final choice = await showUnsavedPlanDialog(context, isSeries: true);
    if (!mounted) return false;
    switch (choice) {
      case UnsavedPlanChoice.save:
        await saveCurrentSeries(ref.container);
        return mounted;
      case UnsavedPlanChoice.discard:
        return true;
      case UnsavedPlanChoice.cancel:
        return false;
    }
  }

  /// Whether the plan being edited may go, asking when it holds unsaved work:
  /// a series with the chance to save it, a single plan as Reset does.
  Future<bool> _confirmReplacingPlan() async {
    final series = ref.read(planSeriesNotifierProvider);
    if (series.savesAsSeries) {
      return series.isDirty ? _confirmReplacingSeries() : true;
    }
    if (!ref.read(divePlanNotifierProvider).isDirty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.divePlanner_action_resetPlan),
        content: Text(context.l10n.divePlanner_message_resetConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.divePlanner_action_reset),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  /// Promote a planned dive by hand (issue #2002): clears the flag and takes
  /// the next dive number through the one path that does both. Invalidates
  /// through the container so the list refreshes even if this page is gone.
  Future<void> _markAsLogged(Dive dive) async {
    // The button stays enabled while the promotion runs, and the same
    // action sits in the overflow menu, so a second call can arrive after
    // the flag is already cleared. convertPlanToActualDive throws then,
    // and nothing awaits this callback, so it must not escape.
    if (_promoting) return;
    _promoting = true;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final failureMessage = context.l10n.diveLog_planned_markLoggedFailed;
    final loggedMessage = context.l10n.diveLog_planned_markedLogged;
    // Read now: a plan marked as logged gets its rules (#3513) even if the
    // diver leaves the page while it is converted.
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    try {
      await ref.read(diveRepositoryProvider).convertPlanToActualDive(dive.id);
    } catch (_) {
      _promoting = false;
      container.invalidate(diveProvider(dive.id));
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return;
    }
    _promoting = false;
    container.invalidate(diveProvider(dive.id));
    container.invalidate(paginatedDiveListProvider);
    container.invalidate(diveListNotifierProvider);
    container.invalidate(divesProvider);
    container.invalidate(diveStatisticsProvider);
    container.invalidate(diveNumberingInfoProvider);
    messenger.showSnackBar(SnackBar(content: Text(loggedMessage)));
    // A plan marked as logged is a dive logged by hand for the logbook
    // rules (#3513).
    await rulesAfterCreate(subject: RuleSubject.dives, ids: [dive.id]);
  }

  Future<void> _scanGalleryForDive(Dive dive) async {
    if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) {
      return;
    }
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final linked = await mediaRepo.getGalleryLinksForDive(dive.id);

      final photoPickerService = ref.read(photoPickerServiceProvider);
      final assets = await TripMediaScanner.scanGalleryForDive(
        dive: dive,
        linked: linked,
        linkedGalleryAssets: ref.read(linkedGalleryAssetsProvider),
        photoPickerService: photoPickerService,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      if (assets == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_diveScan_accessDenied)),
        );
        return;
      }

      if (assets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_diveScan_noPhotosFound)),
        );
        return;
      }

      // Confirm with user
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.media_diveScan_foundTitle),
          content: Text(context.l10n.media_diveScan_foundPhotos(assets.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.media_diveScan_cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                context.l10n.media_diveScan_linkButton(assets.length),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // Show importing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  context.l10n.media_import_importingPhotos(assets.length),
                ),
              ),
            ],
          ),
        ),
      );

      final importService = ref.read(mediaImportServiceProvider);
      final result = await importService.importPhotosForDive(
        selectedAssets: assets,
        dive: dive,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss importing

      // Refresh media providers
      ref.invalidate(mediaForDiveProvider(dive.id));
      ref.invalidate(mediaCountForDiveProvider(dive.id));
      ref.invalidate(divePhotoGpsProvider(dive.id));
      ref.invalidate(allDivePhotoGpsProvider(dive.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.media_import_importedPhotos(result.imported.length),
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_diveScan_error('$e'))),
        );
      }
    }
  }

  Future<void> _confirmAndSplit(Dive dive, String sourceId) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveLog_sources_splitDialog_title),
        content: Text(l10n.diveLog_sources_splitDialog_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.diveLog_sources_splitDialog_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newDiveId = await ref
          .read(diveSplitServiceProvider)
          .split(diveId: dive.id, sourceId: sourceId);
      // Re-scan both the original and the newly split dive (fire-and-forget).
      scheduleQualityScan([dive.id, newDiveId]);
      scheduleSensorSummaryRefresh([dive.id, newDiveId]);
      scheduleDerivedMetricsRefresh([dive.id, newDiveId]);
      _refreshDive(container, dive.id);
      container.invalidate(paginatedDiveListProvider);
      container.invalidate(divesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.diveLog_sources_splitDone),
          showCloseIcon: true,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLog_sources_splitFailed)),
      );
    }
  }

  /// Confirms and runs "Separate combined dives": the inverse of Combine,
  /// and the only recovery path once the merge undo snackbar has dismissed.
  Future<void> _confirmAndSeparate(Dive dive, int segmentCount) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveLog_sources_separateDialog_title),
        content: Text(l10n.diveLog_sources_separateDialog_body(segmentCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.diveLog_sources_separateDialog_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newDiveIds = await ref
          .read(diveUncombineServiceProvider)
          .separate(diveId: dive.id);
      // Re-scan the surviving dive and every restored one (fire-and-forget).
      scheduleQualityScan([dive.id, ...newDiveIds]);
      scheduleSensorSummaryRefresh([dive.id, ...newDiveIds]);
      scheduleDerivedMetricsRefresh([dive.id, ...newDiveIds]);
      _refreshDive(container, dive.id);
      container.invalidate(diveSegmentCountProvider(dive.id));
      container.invalidate(paginatedDiveListProvider);
      container.invalidate(divesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.diveLog_sources_separateDone(newDiveIds.length + 1),
          ),
          showCloseIcon: true,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLog_sources_separateFailed)),
      );
    }
  }

  Future<void> _setPrimarySource(String readingId) async {
    final diveId = this.diveId;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final failureMessage = context.l10n.common_error_tryAgain;
    try {
      await ref
          .read(diveRepositoryProvider)
          .setPrimaryDataSource(diveId: diveId, computerReadingId: readingId);
    } catch (_) {
      // Nothing awaits this callback, so a failure must not escape, and the
      // chip staying as it was would explain nothing.
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return;
    }
    _refreshDive(container, diveId);
  }

  Future<void> _reparseDive(Dive dive) async {
    final service = ref.read(reparseServiceProvider);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final ({List<String> errors, int profilesPreserved}) result;
    try {
      result = await service.reparseDive(
        dive.id,
        parseFn: pigeon.DiveComputerHostApi().parseRawDiveData,
      );
    } catch (e) {
      // The service reports each source's failure in its result. Reading the
      // sources comes before that, and nothing awaits this.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLog_detail_reparseFailed('$e'))),
      );
      return;
    }
    final errors = result.errors;

    // Invalidate providers so the UI reflects the re-parsed data.
    _refreshDive(container, dive.id);

    if (errors.isEmpty) {
      // A combined dive's profile is user-authored, so re-parse refreshes
      // only the source provenance and says so; otherwise the action
      // looks like an unexplained no-op (#1164).
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.profilesPreserved > 0
                ? l10n.diveLog_detail_reparseProfilePreserved
                : l10n.diveLog_detail_reparseSuccess,
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.diveLog_detail_reparseFailed(errors.first)),
        ),
      );
    }
  }

  Future<void> _resyncDive(Dive dive) async {
    if (!demoSealGuard(context, DemoSealedFeature.diveComputerDownload)) return;
    final orchestrator = ref.read(diveResyncOrchestratorProvider);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    DiveResyncOutcome outcome;
    try {
      outcome = await orchestrator.resync(dive.id);
    } catch (_) {
      // The orchestrator's enumerated skip paths never throw; only an
      // unexpected failure while reading/parsing the stored file (e.g. it
      // was corrupted or truncated on disk since import) reaches here, and
      // it must still produce a visible message rather than a silent no-op.
      outcome = const DiveResyncOutcome.failure(
        DiveResyncFailure.unexpectedError,
      );
    }

    _refreshDive(container, dive.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          outcome.succeeded
              // A resync on a combined or multi-source dive refreshes the
              // header and leaves the profile alone; the re-parse path
              // already has the string for exactly that (#1164).
              ? (outcome.profilePreserved
                    ? l10n.diveLog_detail_reparseProfilePreserved
                    : l10n.diveLog_detail_resyncSuccess)
              : diveResyncFailureMessage(
                  l10n,
                  outcome.failureReason ?? DiveResyncFailure.unexpectedError,
                ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.diveLog_delete_title),
        content: Text(context.l10n.diveLog_delete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.diveLog_delete_cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(paginatedDiveListProvider.notifier)
                  .deleteDive(diveId);
              if (mounted) {
                if (widget.embedded && widget.onDeleted != null) {
                  // In embedded mode, call the callback to clear selection
                  widget.onDeleted!();
                } else if (context.canPop()) {
                  // The dive is gone, so this page has to go too, but pop
                  // back to whoever pushed it rather than `go`ing to the list,
                  // which would discard the section the user came from.
                  context.pop();
                } else {
                  // Nothing underneath (deep link / fresh start): fall back to
                  // the list.
                  context.go('/dives');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.diveLog_delete_delete),
          ),
        ],
      ),
    );
  }
}
