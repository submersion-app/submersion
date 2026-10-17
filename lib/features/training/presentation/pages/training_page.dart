import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_list_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_list_page.dart';
import 'package:submersion/features/training/presentation/widgets/training_section_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_route_scope.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

/// Builds one Training tab's list, titled by [headerTitle].
typedef TrainingTabBodyBuilder =
    Widget Function(
      BuildContext context,
      TrainingTab tab,
      SectionHeaderTitle headerTitle,
    );

/// The Training screen: Certifications and Courses as two tabs (#3437).
///
/// Both tab addresses build this page under one page key (see
/// [kTrainingHostPageKey]), so it stays mounted while the address moves
/// between them, and both lists stay alive under it: each keeps its scroll,
/// selection and open form across a switch. A tap on the switch, or a swipe
/// on phone, replaces the address with the other tab's; an address change
/// from anywhere else selects its tab.
class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key, required this.tab, this.tabBodyBuilder});

  /// The tab the current address names.
  final TrainingTab tab;

  /// Builds a tab's list; the real list pages when null.
  final TrainingTabBodyBuilder? tabBodyBuilder;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: TrainingTab.values.length,
    vsync: this,
    initialIndex: widget.tab.index,
  );

  /// The controller index this page last acted on. A change to any other
  /// index came from the switch or a swipe, and moves the address.
  late int _handledIndex = widget.tab.index;

  /// Tabs shown at least once. A tab is built on its first visit, so opening
  /// Training costs no more than opening Certifications did.
  late final Set<TrainingTab> _visited = {widget.tab};

  /// Each tab's last query string at its own address, given back when the
  /// diver returns to it, so a desktop tab reopens on the item it showed.
  final Map<TrainingTab, String> _queries = {};

  /// One focus scope per tab. Focus leaves a tab when it is hidden.
  final Map<TrainingTab, FocusScopeNode> _focusScopes = {
    for (final tab in TrainingTab.values)
      tab: FocusScopeNode(debugLabel: 'Training ${tab.name}'),
  };

  /// What held focus in each tab when it was hidden, handed focus back when
  /// the tab returns. Hiding drops it from the scope's own history, and the
  /// list's keyboard shortcuts only hear keys from inside the list.
  final Map<TrainingTab, FocusNode> _lastFocus = {};

  TrainingTab get _shown => TrainingTab.values[_controller.index];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(TrainingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab && _controller.index != widget.tab.index) {
      _rememberFocus(_shown);
      _handledIndex = widget.tab.index;
      _visited.add(widget.tab);
      _controller.animateTo(widget.tab.index);
      _focusAfterSwitch(widget.tab);
    }
  }

  /// Records what holds focus inside [tab], which is about to be hidden.
  void _rememberFocus(TrainingTab tab) {
    final focus = FocusManager.instance.primaryFocus;
    final scope = _focusScopes[tab]!;
    if (focus != null && focus.ancestors.contains(scope)) {
      _lastFocus[tab] = focus;
    }
  }

  /// Waits for the slide to settle before [_focusAfterSwitch] hands focus
  /// back; null while no switch is pending.
  VoidCallback? _pendingFocus;

  /// Hands focus back to [tab] once the slide has brought it on screen.
  ///
  /// Not sooner: during a tapped switch the [TabBarView] holds its children
  /// back until the slide's future completes, a frame after the slide ends,
  /// so until then the tab still excludes focus. [_focusTab] retries for
  /// that frame.
  void _focusAfterSwitch(TrainingTab tab) {
    final animation = _controller.animation!;
    _cancelPendingFocus();
    void settle() {
      if ((animation.value - tab.index).abs() > 1e-6) return;
      _cancelPendingFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusTab(tab));
    }

    _pendingFocus = settle;
    animation.addListener(settle);
    settle();
  }

  void _cancelPendingFocus() {
    final pending = _pendingFocus;
    if (pending == null) return;
    _controller.animation?.removeListener(pending);
    _pendingFocus = null;
  }

  void _focusTab(TrainingTab tab, {int retries = 3}) {
    if (!mounted || _shown != tab) return;
    final last = _lastFocus[tab];
    if (last != null && last.context != null) {
      if (last.canRequestFocus) {
        last.requestFocus();
        return;
      }
      if (retries > 0) {
        WidgetsBinding.instance
          ..addPostFrameCallback((_) => _focusTab(tab, retries: retries - 1))
          ..scheduleFrame();
        return;
      }
    }
    _focusScopes[tab]!.requestFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _cancelPendingFocus();
    _controller.dispose();
    for (final scope in _focusScopes.values) {
      scope.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    final index = _controller.index;
    if (index == _handledIndex) return;
    _rememberFocus(TrainingTab.values[_handledIndex]);
    _handledIndex = index;
    final tab = TrainingTab.values[index];
    setState(() => _visited.add(tab));
    _focusAfterSwitch(tab);
    final query = _queries[tab] ?? '';
    context.goInPlace(query.isEmpty ? tab.path : '${tab.path}?$query');
  }

  /// [tab]'s list, cut off from the route while it is hidden: a kept-alive
  /// tab stays in the route's tree, so its keyboard shortcuts, its Back
  /// handling and its add button's hero would otherwise act alongside the
  /// tab on screen.
  Widget _buildTab(BuildContext context, TrainingTab tab) {
    final visible = tab == _shown;
    return TabVisibility(
      visible: visible,
      child: HeroMode(
        enabled: visible,
        child: ExcludeFocus(
          excluding: !visible,
          child: FocusScope(
            node: _focusScopes[tab],
            child: MasterDetailRouteScope(
              path: tab.path,
              child: _buildBody(context, tab),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TrainingTab tab) {
    final headerTitle = trainingHeaderTitle(controller: _controller, tab: tab);
    final builder = widget.tabBodyBuilder;
    if (builder != null) return builder(context, tab, headerTitle);
    return switch (tab) {
      TrainingTab.certifications => CertificationListPage(
        headerTitle: headerTitle,
      ),
      TrainingTab.courses => CourseListPage(headerTitle: headerTitle),
    };
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final current = trainingTabForPath(uri.path);
    if (current != null) _queries[current] = uri.query;

    return TabBarView(
      controller: _controller,
      // Swiping is for phone layouts; on desktop a sideways trackpad gesture
      // would fight the list and the table.
      physics: ResponsiveBreakpoints.isMasterDetail(context)
          ? const NeverScrollableScrollPhysics()
          : null,
      children: [
        for (final tab in TrainingTab.values)
          _visited.contains(tab)
              ? _KeepAlive(child: _buildTab(context, tab))
              : const SizedBox.shrink(),
      ],
    );
  }
}

/// Keeps a tab's subtree alive while the [TabBarView] shows the other one.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
