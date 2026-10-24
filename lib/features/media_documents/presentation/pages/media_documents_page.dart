import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/pages/documents_page.dart';
import 'package:submersion/features/media/presentation/pages/media_section_page.dart';
import 'package:submersion/features/media_documents/presentation/widgets/media_documents_section_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_route_scope.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

/// Builds one Media/Documents tab's body, titled by [headerTitle].
typedef MediaDocumentsTabBodyBuilder =
    Widget Function(
      BuildContext context,
      MediaDocumentsTab tab,
      SectionHeaderTitle headerTitle,
    );

/// The Media and Documents screen: Media and Documents as two tabs (#3631),
/// following Training's Certifications/Courses merge (#3437).
///
/// Both tab addresses build this page under one page key (see
/// [kMediaDocumentsHostPageKey]), so it stays mounted while the address
/// moves between them, and both tabs stay alive under it: each keeps its
/// scroll, selection and open form across a switch. A tap on the switch, or
/// a swipe on phone, replaces the address with the other tab's; an address
/// change from anywhere else selects its tab.
///
/// A switch works the way Training's does. On desktop the other tab shows in
/// place at once. On phone the list slides, but under a header that stays
/// put: each tab's own app bar is held still by [mediaDocumentsHeaderTitle].
class MediaDocumentsPage extends StatefulWidget {
  const MediaDocumentsPage({super.key, required this.tab, this.tabBodyBuilder});

  /// The tab the current address names.
  final MediaDocumentsTab tab;

  /// Builds a tab's body; the real page when null.
  final MediaDocumentsTabBodyBuilder? tabBodyBuilder;

  @override
  State<MediaDocumentsPage> createState() => _MediaDocumentsPageState();
}

class _MediaDocumentsPageState extends State<MediaDocumentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: MediaDocumentsTab.values.length,
    vsync: this,
    initialIndex: widget.tab.index,
  );

  /// The controller index this page last acted on. A change to any other
  /// index came from the switch or a swipe, and moves the address.
  late int _handledIndex = widget.tab.index;

  /// Tabs shown at least once. On desktop a tab is built on its first visit,
  /// so opening Media and Documents costs no more than opening Media did.
  late final Set<MediaDocumentsTab> _visited = {widget.tab};

  /// Each tab's last query string at its own address, given back when the
  /// diver returns to it, so Documents' filters (type/expiring/personal/tag)
  /// survive a round trip through the Media tab.
  final Map<MediaDocumentsTab, String> _queries = {};

  /// One focus scope per tab. Focus leaves a tab when it is hidden.
  final Map<MediaDocumentsTab, FocusScopeNode> _focusScopes = {
    for (final tab in MediaDocumentsTab.values)
      tab: FocusScopeNode(debugLabel: 'MediaDocuments ${tab.name}'),
  };

  /// What held focus in each tab when it was hidden, handed focus back when
  /// the tab returns.
  final Map<MediaDocumentsTab, FocusNode> _lastFocus = {};

  /// One key per tab, so a tab keeps its state when a resize across the
  /// master-detail breakpoint moves it between the phone's [TabBarView] and
  /// the desktop's stack.
  final Map<MediaDocumentsTab, GlobalKey> _tabKeys = {
    for (final tab in MediaDocumentsTab.values)
      tab: GlobalKey(debugLabel: 'MediaDocuments ${tab.name}'),
  };

  MediaDocumentsTab get _shown => MediaDocumentsTab.values[_controller.index];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(MediaDocumentsPage oldWidget) {
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
  void _rememberFocus(MediaDocumentsTab tab) {
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
  void _focusAfterSwitch(MediaDocumentsTab tab) {
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

  void _focusTab(MediaDocumentsTab tab, {int retries = 3}) {
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
    _rememberFocus(MediaDocumentsTab.values[_handledIndex]);
    _handledIndex = index;
    final tab = MediaDocumentsTab.values[index];
    setState(() => _visited.add(tab));
    _focusAfterSwitch(tab);
    final query = _queries[tab] ?? '';
    context.goInPlace(query.isEmpty ? tab.path : '${tab.path}?$query');
  }

  /// [tab]'s body, cut off from the route while it is hidden, and scoped so
  /// its own master-detail selection (Documents' today) only reads the URL
  /// while this tab's address is the active one.
  Widget _buildTab(BuildContext context, MediaDocumentsTab tab) {
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
              child: _buildBody(context, tab),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MediaDocumentsTab tab) {
    final headerTitle = mediaDocumentsHeaderTitle(
      controller: _controller,
      tab: tab,
    );
    final builder = widget.tabBodyBuilder;
    if (builder != null) return builder(context, tab, headerTitle);
    return switch (tab) {
      MediaDocumentsTab.media => MediaSectionPage(headerTitle: headerTitle),
      MediaDocumentsTab.documents => _documentsPage(headerTitle),
    };
  }

  /// Documents' body, with its initial filters read from this tab's own
  /// `_queries` entry rather than from whichever route last rebuilt this
  /// page. Both `/documents` and `/media` keep that entry current (see
  /// [build]'s `_queries` update), so the filters survive a round trip
  /// through the Media tab instead of resetting whenever the active route
  /// is `/media` (#3631 code review).
  Widget _documentsPage(SectionHeaderTitle headerTitle) {
    final q = Uri.splitQueryString(_queries[MediaDocumentsTab.documents] ?? '');
    return DocumentsPage(
      initialType: DocumentType.values.asNameMap()[q['type']],
      initialExpiringOnly: q['filter'] == 'expiring',
      initialPersonalOnly: q['owner'] == 'personal',
      initialTagId: q['tag'],
      headerTitle: headerTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final current = mediaDocumentsTabForPath(uri.path);
    if (current != null) _queries[current] = uri.query;

    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final tab in MediaDocumentsTab.values)
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

    return TabBarView(
      controller: _controller,
      children: [
        for (final tab in MediaDocumentsTab.values)
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
