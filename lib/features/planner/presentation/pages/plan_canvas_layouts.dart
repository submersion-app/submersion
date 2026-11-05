part of 'plan_canvas_page.dart';

/// The planner's layouts (issue #3565 moved them out of the page): the
/// desktop panes around the chart, and the phone's chart box and tabs, each
/// of which shows a logged dive picked in the series bar read-only in the
/// planned dive's place.
mixin _PlanCanvasLayouts on ConsumerState<PlanCanvasPage> {
  /// The results pane's scroll position, which the page owns.
  ScrollController get _wideResultsController;

  /// Desktop: the editor pane is always visible (collapsible, never hidden
  /// behind a drawer). At full width the results pane shows by default; at
  /// middle widths it defaults to hidden and the right chevron reveals it.
  Widget _buildDesktop({required bool fullWidth}) {
    // A logged dive picked in the series bar keeps this layout: each pane
    // shows it read-only in the planned dive's place (issue #3565).
    final logged = ref.watch(viewingLoggedDiveProvider);
    // The plan of a dive that has been dived is the record of what was
    // planned, so it shows read-only.
    final planOfDived = ref.watch(_planOfDivedProvider);
    final editorCollapsed = ref.watch(editorPaneCollapsedProvider);
    final resultsVisible = fullWidth
        ? !ref.watch(resultsPaneCollapsedProvider)
        : ref.watch(resultsPaneNarrowExpandedProvider);

    void toggleResults() {
      if (fullWidth) {
        ref.read(resultsPaneCollapsedProvider.notifier).update((v) => !v);
      } else {
        ref.read(resultsPaneNarrowExpandedProvider.notifier).update((v) => !v);
      }
    }

    return Row(
      children: [
        if (!editorCollapsed) ...[
          SizedBox(
            width: 320,
            child: IgnorePointer(
              ignoring: planOfDived,
              child: const PlanEditorPane(),
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          child: _chartColumn(
            editorCollapsed: editorCollapsed,
            onToggleEditor: () => ref
                .read(editorPaneCollapsedProvider.notifier)
                .update((v) => !v),
            resultsVisible: resultsVisible,
            onToggleResults: toggleResults,
          ),
        ),
        if (resultsVisible) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: logged
                ? LoggedDiveResults(controller: _wideResultsController)
                : PlanResultsPane(controller: _wideResultsController),
          ),
        ],
      ],
    );
  }

  Widget _chartColumn({
    required bool editorCollapsed,
    required VoidCallback onToggleEditor,
    required bool resultsVisible,
    required VoidCallback onToggleResults,
  }) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: PlanSeriesNavigator(),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: PlanActualToggle(),
        ),
        if (logged == null) const PlanFollowPrompt(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  // The dive log's chart has a header row of its own, which
                  // starts below the pane buttons rather than under them.
                  padding: logged == null
                      ? const EdgeInsets.all(12)
                      : const EdgeInsets.fromLTRB(12, 48, 12, 12),
                  child: logged == null
                      ? const PlanProfileChart()
                      : LoggedDiveChart(diveId: logged.id),
                ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: IconButton(
                  tooltip: editorCollapsed
                      ? context.l10n.plannerCanvas_pane_expand
                      : context.l10n.plannerCanvas_pane_collapse,
                  icon: Icon(
                    editorCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: onToggleEditor,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton(
                  tooltip: resultsVisible
                      ? context.l10n.plannerCanvas_pane_collapse
                      : context.l10n.plannerCanvas_pane_expand,
                  icon: Icon(
                    resultsVisible ? Icons.chevron_right : Icons.chevron_left,
                  ),
                  onPressed: onToggleResults,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: logged == null
              ? PlanStatusChips(onIssuesTap: _scrollWideToIssues)
              : LoggedDiveStatusChips(onWarningsTap: _scrollWideToIssues),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: logged == null
              ? const Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [ContingencyChips(), ChartModeToggle()],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPhone(BoxConstraints constraints) {
    final tab = ref.watch(plannerPhoneTabProvider);
    // Tanks first: the gas is chosen before the profile that breathes it, and
    // the deck's default index of 0 therefore opens on Tanks. Setup and
    // Results keep indices 2 and 3, which _focusSetup and the issues chip
    // write directly.
    final tabs = [
      context.l10n.divePlanner_label_tanks,
      context.l10n.divePlanner_tab_plan,
      context.l10n.plannerCanvas_tab_setup,
      context.l10n.divePlanner_tab_results,
    ];
    // 30% of the body, clamped so the chart neither vanishes on short
    // viewports nor dominates tall ones; the deck gets everything else.
    final chartHeight = (constraints.maxHeight * 0.30)
        .clamp(160.0, 260.0)
        .toDouble();
    // A logged dive picked in the series bar keeps this layout: the same
    // chart box and tabs, each showing it read-only (issue #3565). Its chart
    // carries nothing over it: the dive log's chart has its axis at the
    // foot, and its runtime and warnings lead its Results. Setup is
    // never its own, and Plan only when it was dived from a plan; a tab it
    // cannot show falls back to Tanks, and the choice comes back on a
    // planned dive.
    final logged = ref.watch(viewedLoggedDiveProvider);
    final loggedPlan = ref.watch(viewedLoggedDivePlanStateProvider);
    bool tabEnabled(int i) =>
        logged == null || i == 0 || i == 3 || (i == 1 && loggedPlan != null);
    final shownTab = tabEnabled(tab) ? tab : 0;
    // A single CustomScrollView so the chart and tab selector scroll away
    // with the rest of the page instead of staying pinned and eating the
    // viewport (#1428).
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: PlanSeriesNavigator()),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: PlanActualToggle(),
          ),
        ),
        if (logged == null) const SliverToBoxAdapter(child: PlanFollowPrompt()),
        SliverToBoxAdapter(
          child: SizedBox(
            height: chartHeight,
            child: logged != null
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: LoggedDiveChart(diveId: logged.id),
                  )
                : _phonePlanChart(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < tabs.length; i++)
                  ButtonSegment(
                    value: i,
                    label: Text(tabs[i]),
                    enabled: tabEnabled(i),
                  ),
              ],
              selected: {shownTab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(plannerPhoneTabProvider.notifier).state =
                      selection.first,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: logged == null
              ? IgnorePointer(
                  ignoring: ref.watch(_planOfDivedProvider),
                  child: _phoneTabBody(shownTab),
                )
              : _phoneLoggedTabBody(shownTab, loggedPlan),
        ),
      ],
    );
  }

  /// The plan's chart on a phone, with its readouts, chips and full-screen
  /// button laid over it.
  Widget _phonePlanChart() {
    return Stack(
      children: [
        const Positioned.fill(
          child: Padding(padding: EdgeInsets.all(8), child: PlanProfileChart()),
        ),
        PlanChartReadouts(
          onIssuesTap: () =>
              ref.read(plannerPhoneTabProvider.notifier).state = 3,
        ),
        const Positioned(
          left: 8,
          right: 56,
          bottom: 8,
          child: Align(
            alignment: Alignment.bottomLeft,
            // Both chip groups scroll together, not just
            // ContingencyChips' own inner scroll view: nested inside
            // a plain Row here, that inner view took its full
            // natural width instead of yielding to the Bailout/CCR
            // chips, overflowing this bar on a narrow phone (the
            // combined width of every chip no longer fits #3130).
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContingencyChips(overlay: true),
                  SizedBox(width: 6),
                  ChartModeToggle(),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: IconButton.filledTonal(
            icon: const Icon(Icons.open_in_full, size: 18),
            // PUSH (not go): back returns to this canvas with its
            // state on the stack, instead of closing the app (#647).
            onPressed: () => context.push('/planning/dive-planner/chart'),
          ),
        ),
      ],
    );
  }

  Widget _phoneTabBody(int tab) {
    switch (tab) {
      case 0:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [PlanDiveDetailsCard(), PlanTankList()]),
        );
      case 1:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SegmentList(),
        );
      case 2:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: PlanSetupAccordion(),
        );
      case 3:
      default:
        return PlanResultsPane(
          controller: _wideResultsController,
          shrinkWrap: true,
        );
    }
  }

  /// A logged dive's tabs: Tanks, its plan's segments, and Results.
  Widget _phoneLoggedTabBody(int tab, DivePlanState? plan) {
    switch (tab) {
      case 1 when plan != null:
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SegmentList(plan: plan),
        );
      case 3:
        return LoggedDiveResults(
          controller: _wideResultsController,
          shrinkWrap: true,
        );
      default:
        return const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [LoggedDiveDetailsCard(), LoggedDiveTanksCard()],
          ),
        );
    }
  }

  /// The results pane is always visible outside phone mode; scroll it to the
  /// issues section (the last one) when the issues chip is tapped.
  void _scrollWideToIssues() {
    if (!_wideResultsController.hasClients) return;
    _wideResultsController.animateTo(
      _wideResultsController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

/// Whether the planner shows the plan of a dive that has been dived, which
/// is read-only (issue #3565).
final _planOfDivedProvider = Provider<bool>(
  (ref) =>
      ref.watch(selectedDiveActualProvider) != null &&
      ref.watch(showPlanOfDivedProvider),
);
