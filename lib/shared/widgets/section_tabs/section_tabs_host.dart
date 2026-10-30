import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_route_scope.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tab.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tabs_header_title.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

/// Builds one tab's body, titled by [headerTitle]. [query] is the tab's own
/// last query string at its address, parsed, which stays put while the other
/// tab's address is the active one.
typedef SectionTabBodyBuilder<T extends SectionTab> =
    Widget Function(
      BuildContext context,
      T tab,
      SectionHeaderTitle headerTitle,
      Map<String, String> query,
    );

/// A nav entry's screen that holds two sections as tabs, such as Training's
/// Certifications and Courses (#3437) and Media's Photos/Videos and
/// Documents (#3631).
///
/// Every tab address builds this host under one page key (see
/// [sectionTabsHostPage]), so it stays mounted while the address moves
/// between them, and every tab stays alive under it: each keeps its scroll,
/// selection and open form across a switch. A tap on the switch, or a swipe
/// on phone, replaces the address with the other tab's; an address change
/// from anywhere else selects its tab.
///
/// A switch works the way Equipment's does (#3465). On desktop the other tab
/// shows in place at once. On phone the body slides, but under a header that
/// stays put: each tab's own app bar is held still by
/// [sectionTabsHeaderTitle].
class SectionTabsHost<T extends SectionTab> extends StatefulWidget {
  const SectionTabsHost({
    super.key,
    required this.tabs,
    required this.tab,
    required this.labels,
    required this.toggleKey,
    required this.bodyBuilder,
  });

  /// Every tab, in on-screen order: the enum's `values`.
  final List<T> tabs;

  /// The tab the current address names.
  final T tab;

  /// The switch's names for [tabs], in the same order.
  final List<String> Function(BuildContext context) labels;

  /// Keys the switch's [TabBar].
  final Key toggleKey;

  final SectionTabBodyBuilder<T> bodyBuilder;

  @override
  State<SectionTabsHost<T>> createState() => _SectionTabsHostState<T>();
}

class _SectionTabsHostState<T extends SectionTab>
    extends State<SectionTabsHost<T>>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: widget.tabs.length,
    vsync: this,
    initialIndex: widget.tab.index,
  );

  /// The controller index this host last acted on. A change to any other
  /// index came from the switch or a swipe, and moves the address.
  late int _handledIndex = widget.tab.index;

  /// Tabs shown at least once. On desktop a tab is built on its first visit,
  /// so opening the host costs no more than opening its first tab did. The
  /// phone's [TabBarView] needs no help there: its pages are built as they
  /// slide into view.
  late final Set<T> _visited = {widget.tab};

  /// Each tab's last query string at its own address, given back when the
  /// diver returns to it, so a desktop tab reopens on the item it showed and
  /// a tab's filters survive a round trip through the other tab.
  final Map<T, String> _queries = {};

  /// One focus scope per tab. Focus leaves a tab when it is hidden.
  late final Map<T, FocusScopeNode> _focusScopes = {
    for (final tab in widget.tabs)
      tab: FocusScopeNode(debugLabel: 'SectionTabs ${tab.name}'),
  };

  /// What held focus in each tab when it was hidden, handed focus back when
  /// the tab returns. Hiding drops it from the scope's own history, and a
  /// list's keyboard shortcuts only hear keys from inside the list.
  final Map<T, FocusNode> _lastFocus = {};

  /// One key per tab, so a tab keeps its state when a resize across the
  /// master-detail breakpoint moves it between the phone's [TabBarView] and
  /// the desktop's stack.
  late final Map<T, GlobalKey> _tabKeys = {
    for (final tab in widget.tabs)
      tab: GlobalKey(debugLabel: 'SectionTabs ${tab.name}'),
  };

  T get _shown => widget.tabs[_controller.index];

  @override
  void initState() {
    super.initState();
    assert(
      widget.tabs.indexed.every((entry) => entry.$2.index == entry.$1),
      'tabs must be the enum values in declaration order',
    );
    _controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(SectionTabsHost<T> oldWidget) {
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
  void _rememberFocus(T tab) {
    final focus = FocusManager.instance.primaryFocus;
    final scope = _focusScopes[tab]!;
    if (focus != null && focus.ancestors.contains(scope)) {
      _lastFocus[tab] = focus;
    }
  }

  /// Waits for the slide to settle before [_focusAfterSwitch] hands focus
  /// back; null while no switch is pending.
  VoidCallback? _pendingFocus;

  /// Hands focus back to [tab] once the switch's animation has settled.
  ///
  /// Not sooner: during a tapped switch on phone the [TabBarView] holds its
  /// children back until the slide's future completes, a frame after the
  /// slide ends, so until then the tab still excludes focus. [_focusTab]
  /// retries for that frame. On desktop the tab is on screen at once, and
  /// the wait is only the switch's own underline sliding across.
  void _focusAfterSwitch(T tab) {
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

  void _focusTab(T tab, {int retries = 3}) {
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
    _rememberFocus(widget.tabs[_handledIndex]);
    _handledIndex = index;
    final tab = widget.tabs[index];
    setState(() => _visited.add(tab));
    _focusAfterSwitch(tab);
    final query = _queries[tab] ?? '';
    context.goInPlace(query.isEmpty ? tab.path : '${tab.path}?$query');
  }

  /// [tab]'s body, cut off from the route while it is hidden: a kept-alive
  /// tab stays in the route's tree, so its keyboard shortcuts, its Back
  /// handling and its add button's hero would otherwise act alongside the
  /// tab on screen. Its master-detail selection only reads the URL while
  /// its own address is the active one.
  Widget _buildTab(BuildContext context, T tab) {
    final visible = tab == _shown;
    return TabVisibility(
      key: _tabKeys[tab],
      visible: visible,
      child: HeroMode(
        enabled: visible,
        child: ExcludeFocus(
          excluding: !visible,
          child: FocusScope(
            node: _focusScopes[tab],
            child: MasterDetailRouteScope(
              path: tab.path,
              child: widget.bodyBuilder(
                context,
                tab,
                sectionTabsHeaderTitle(
                  controller: _controller,
                  tab: tab,
                  labels: widget.labels,
                  toggleKey: widget.toggleKey,
                ),
                Uri.splitQueryString(_queries[tab] ?? ''),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final current = sectionTabForPath(widget.tabs, uri.path);
    if (current != null) _queries[current] = uri.query;

    // Desktop shows the other tab in place, as Equipment does. A TabBarView
    // slides even with swiping off, since a tap animates it to the tab, and
    // there a sideways trackpad gesture would fight the list and the table.
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final tab in widget.tabs)
            if (_visited.contains(tab))
              Visibility(
                key: ValueKey(tab),
                visible: tab == _shown,
                maintainState: true,
                child: _buildTab(context, tab),
              ),
        ],
      );
    }

    // Every page is the real tab, never a placeholder until its first visit.
    // A tapped switch freezes the TabBarView's children until the slide ends,
    // so a placeholder would slide in blank, taking the header with it at the
    // halfway point where the pinned bars hand over.
    return TabBarView(
      controller: _controller,
      children: [
        for (final tab in widget.tabs)
          _KeepAlive(child: _buildTab(context, tab)),
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
