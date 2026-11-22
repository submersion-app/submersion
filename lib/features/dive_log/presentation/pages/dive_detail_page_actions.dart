part of 'dive_detail_page.dart';

/// What the dive detail page does on the diver's behalf. These take dialogs and
/// imports to finish, so they run on the page, which is there to report the
/// result whatever happens to the section that started one.
mixin _DiveDetailPageActions on ConsumerState<DiveDetailPage> {
  /// A promotion of a planned dive is in flight (issue #2002), so a second
  /// tap on the banner or the menu item is ignored rather than calling
  /// convertPlanToActualDive on a dive that is no longer planned.
  bool _promoting = false;

  /// The dive this page shows: on a new dive's page, the id the dive is
  /// given now and created under at Save (issue #4527, plan 8).
  String get diveId => widget.newDiveRequest == null ? widget.diveId : _newId;

  late final String _newId = const Uuid().v4();

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

  /// Reads heart rate, recovery and sleep from Apple Health for [dive]
  /// (issue #637), for a dive the automatic read never reached. Says so
  /// when Health has nothing for it.
  Future<bool> _addHeartRate(Dive dive) async {
    final metrics = ref.read(diveHealthMetricsServiceProvider);
    if (metrics == null) return false;
    final records = ref.read(diveHealthRecordRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    String? problem;
    try {
      await metrics.refresh(dive.id);
      if (!diveHealthHasContent(await records.forDive(dive.id))) {
        problem = l10n.diveLog_health_noneFound;
      }
    } catch (_) {
      problem = l10n.diveLog_health_readFailed;
    }
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
    }
    return true;
  }

  Future<bool> _linkPreDiveChecklist(Dive dive) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = context.l10n.preDive_link_linked;
    final failureMessage = context.l10n.common_error_tryAgain;
    final repository = ref.read(preDiveSessionRepositoryProvider);
    final sessionId = await showLinkSessionPicker(
      context,
      diverId: dive.diverId,
    );
    if (sessionId == null) return false;
    try {
      await repository.linkToDive(sessionId, dive.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return true;
    }
    // Nothing on this page renders the link, so the snackbar is the only
    // evidence the write happened.
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
    return true;
  }

  Future<bool> _unlinkPreDiveChecklist(PreDiveSession linked) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = context.l10n.preDive_link_unlinked;
    final failureMessage = context.l10n.common_error_tryAgain;
    try {
      await ref
          .read(preDiveSessionRepositoryProvider)
          .unlinkFromDive(linked.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return true;
    }
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
    return true;
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
        // A first save asks for a name, as the planner's Save does.
        if (ref.read(planSeriesNotifierProvider).id == null &&
            (!await nameFirstSave(context, ref) || !mounted)) {
          return false;
        }
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
  /// Marks a plan as logged, or a draft as complete (issue #637): both go
  /// through the one promotion that clears the flag and assigns the next
  /// number.
  ///
  /// Like each whole-record operation here, it answers whether it tried to
  /// write (a failed write counts: the dive is read again either way).
  Future<bool> _markAsLogged(Dive dive) async {
    // The button stays enabled while the promotion runs, and the same
    // action sits in the overflow menu, so a second call can arrive after
    // the flag is already cleared. The promotion throws then, and nothing
    // awaits this callback, so it must not escape.
    if (_promoting) return false;
    _promoting = true;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final failureMessage = dive.isDraft
        ? l10n.diveLog_draft_markCompleteFailed
        : l10n.diveLog_planned_markLoggedFailed;
    final loggedMessage = dive.isDraft
        ? l10n.diveLog_draft_markedComplete
        : l10n.diveLog_planned_markedLogged;
    // Read now: a plan marked as logged gets its rules (#3513) even if the
    // diver leaves the page while it is converted.
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    try {
      if (dive.isDraft) {
        await ref.read(diveDraftRepositoryProvider).markDraftComplete(dive.id);
      } else {
        await ref.read(diveRepositoryProvider).convertPlanToActualDive(dive.id);
      }
    } catch (_) {
      _promoting = false;
      container.invalidate(diveProvider(dive.id));
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      return true;
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
    // rules (#3513), and so is a draft marked complete.
    await rulesAfterCreate(subject: RuleSubject.dives, ids: [dive.id]);
    return true;
  }

  /// Closes an open draft now, from its banner (issue #637). The site
  /// buttons on the GPS log record a position as well; this one has none.
  Future<bool> _surfaceDraft(Dive dive) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await ref
          .read(diveDraftRepositoryProvider)
          .closeDraft(dive.id, exitTime: asWallClockUtc(DateTime.now()));
    } catch (e, stackTrace) {
      // Filled or closed on another device meanwhile (closeDraft throws on
      // a dive that is no longer a draft), or a failed write. Nothing awaits
      // this callback, so it must not escape; the reload shows the dive as
      // it now is.
      _log.error(
        'Failed to mark a draft surfaced',
        error: e,
        stackTrace: stackTrace,
      );
    }
    container.invalidate(diveProvider(dive.id));
    return true;
  }

  /// A draft's "Download now" (issue #637): opens the download of the
  /// computer the diver used last, or the computer picker when there is none.
  Future<void> _downloadForDraft() async {
    final target = await ref.read(downloadTargetComputerProvider.future);
    if (!mounted) return;
    context.push(downloadRouteFor(target));
  }

  Future<bool> _confirmAndSplit(Dive dive, String sourceId) async {
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
    if (confirmed != true || !mounted) return false;
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
    return true;
  }

  /// Runs Remove source (issue #4393) through the flow the inbox shares.
  /// After the removal and after its Undo the dive refreshes, and a source
  /// the chart was showing or overlaying stops being asked for once gone.
  /// It offers no Undo: the removal reverts from History (issue #4527).
  Future<bool> _confirmAndRemoveSource(
    Dive dive,
    String sourceId,
    String sourceName,
  ) {
    final container = ProviderScope.containerOf(context, listen: false);
    void afterChange() {
      final active = container.read(activeDiveSourceProvider(dive.id).notifier);
      if (active.state == sourceId) active.state = null;
      final overlays = container.read(overlaySourcesProvider(dive.id).notifier);
      if (overlays.state.contains(sourceId)) {
        overlays.state = {...overlays.state}..remove(sourceId);
      }
      scheduleQualityScan([dive.id]);
      scheduleSensorSummaryRefresh([dive.id], force: true);
      scheduleDerivedMetricsRefresh([dive.id], force: true);
      _refreshDive(container, dive.id);
      container.invalidate(paginatedDiveListProvider);
      container.invalidate(divesProvider);
    }

    return removeSourceWithUndo(
      context,
      ref,
      diveId: dive.id,
      sourceId: sourceId,
      sourceName: sourceName,
      afterChange: afterChange,
      offerUndo: false,
    );
  }

  /// Confirms and runs "Separate combined dives": the inverse of Combine,
  /// and the only recovery path once the merge undo snackbar has dismissed.
  Future<bool> _confirmAndSeparate(Dive dive, int segmentCount) async {
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
    if (confirmed != true || !mounted) return false;
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
    return true;
  }

  Future<bool> _setPrimarySource(String readingId) async {
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
      return true;
    }
    _refreshDive(container, diveId);
    return true;
  }

  /// Asks which of [changes], values the diver set by hand that a re-parse
  /// or resync would replace, to keep (issue #4909). The changes to make,
  /// none when nothing would change or the page is gone, or null when the
  /// diver cancels. Each
  /// carries the value the diver saw, so the write replaces nothing that
  /// changed since.
  Future<List<HandSetChange>?> _reviewHandSet(
    List<HandSetChange> changes,
    HandSetReviewSource source,
  ) async {
    // A diver who left while the preview ran is not asked: the operation
    // carries on as it would after they left, keeping every value they set.
    if (changes.isEmpty || !mounted) return const [];
    final replace = await showHandSetReviewDialog(
      context,
      changes: changes,
      source: source,
      units: ref.read(unitFormatterProvider),
    );
    if (replace == null) return null;
    return [
      for (final change in changes)
        if (replace.contains(change.field)) change,
    ];
  }

  Future<bool> _reparseDive(Dive dive) async {
    final service = ref.read(reparseServiceProvider);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final parseFn = pigeon.DiveComputerHostApi().parseRawDiveData;

    final ({List<String> errors, int profilesPreserved}) result;
    try {
      final replace = await _reviewHandSet(
        await service.previewReparse(dive.id, parseFn: parseFn),
        HandSetReviewSource.computer,
      );
      if (replace == null) return false;
      result = await service.reparseDive(
        dive.id,
        parseFn: parseFn,
        replaceHandSet: replace,
      );
    } catch (e) {
      // The service reports each source's failure in its result. Reading the
      // sources comes before that, and nothing awaits this.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLog_detail_reparseFailed('$e'))),
      );
      return true;
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
          content: Text(
            l10n.diveLog_detail_reparseFailed(
              reparseErrorLabel(l10n, errors.first),
            ),
          ),
        ),
      );
    }
    return true;
  }

  Future<bool> _resyncDive(Dive dive) async {
    if (!demoSealGuard(context, DemoSealedFeature.diveComputerDownload)) {
      return false;
    }
    final orchestrator = ref.read(diveResyncOrchestratorProvider);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    DiveResyncOutcome outcome;
    try {
      final replace = await _reviewHandSet(
        await orchestrator.previewHandSetChanges(dive.id),
        HandSetReviewSource.file,
      );
      if (replace == null) return false;
      outcome = await orchestrator.resync(dive.id, replaceHandSet: replace);
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
    return true;
  }

  /// Asks, then deletes the dive. True when it was deleted.
  Future<bool> _confirmAndDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveLog_delete_title),
        content: Text(l10n.diveLog_delete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.diveLog_delete_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.diveLog_delete_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    await ref.read(paginatedDiveListProvider.notifier).deleteDive(diveId);
    return true;
  }

  /// The page has gone with its dive: back to whoever opened it.
  /// Set once the page leaves a deleted dive. The delete ended the sitting
  /// just before, and a report of that end ([_DiveDetailPageUnlockOpen])
  /// would send the list pane back to a dive that is gone.
  bool _leftDeletedDive = false;

  void _leaveDeletedDive() {
    if (!mounted) return;
    _leftDeletedDive = true;
    if (widget.embedded && widget.onDeleted != null) {
      // In embedded mode, call the callback to clear selection
      widget.onDeleted!();
    } else if (context.canPop()) {
      // The dive is gone, so this page has to go too, but pop back to
      // whoever pushed it rather than `go`ing to the list, which would
      // discard the section the user came from.
      context.pop();
    } else {
      // Nothing underneath (deep link / fresh start): fall back to the
      // list.
      context.go('/dives');
    }
  }
}
