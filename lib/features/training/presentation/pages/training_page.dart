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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(TrainingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab && _controller.index != widget.tab.index) {
      _handledIndex = widget.tab.index;
      _visited.add(widget.tab);
      _controller.animateTo(widget.tab.index);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final index = _controller.index;
    if (index == _handledIndex) return;
    _handledIndex = index;
    final tab = TrainingTab.values[index];
    setState(() => _visited.add(tab));
    final query = _queries[tab] ?? '';
    context.goInPlace(query.isEmpty ? tab.path : '${tab.path}?$query');
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
              ? _KeepAlive(
                  child: MasterDetailRouteScope(
                    path: tab.path,
                    child: _buildBody(context, tab),
                  ),
                )
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
