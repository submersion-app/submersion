import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/section_navigation.dart';

/// Opening settings pages from a page that may sit in the desktop settings
/// pane.
extension SettingsPaneNavigation on BuildContext {
  /// Opens the settings page at [location].
  ///
  /// Inside a [SettingsPaneNavigator] that can show [location], the page opens
  /// in the pane; anywhere else (a phone, or a location the pane does not
  /// show) the route is pushed as before. The future completes when the page
  /// closes.
  Future<void> pushSettingsPage(String location) {
    final pane = _SettingsPaneScope.maybeOf(this);
    if (pane != null && pane.canShow(location)) return pane.open(location);
    return push<Object?>(location);
  }

  /// Replaces the page this context is on with the settings page at
  /// [location], in the pane or as a route like [pushSettingsPage].
  void replaceSettingsPage(String location) {
    final pane = _SettingsPaneScope.maybeOf(this);
    if (pane != null && pane.canShow(location)) {
      pane.replaceTop(location);
    } else {
      pushReplacement(location);
    }
  }
}

/// A settings section in the desktop detail pane whose pages open inside the
/// pane rather than over the whole window (issue #3467).
///
/// The URL carries the open pages, so the section list stays on the section,
/// Back walks up one page at a time, and a deep link or window restore
/// reopens them: `/settings?selected=<sectionId>` is [hub], and each
/// `&<queryParam>=<path>` stacks the page at `/settings/<path>` on top of it.
/// Pages open more pages with [SettingsPaneNavigation.pushSettingsPage]; a
/// plain `Navigator.pop` closes one.
class SettingsPaneNavigator extends StatefulWidget {
  /// The settings section this pane shows, its `selected` value.
  final String sectionId;

  /// The query parameter holding the open pages, outermost first.
  final String queryParam;

  /// The section's own content, under every page.
  final Widget hub;

  /// The page for a location under `/settings/`, or null when the pane does
  /// not show it.
  final Widget? Function(Uri location) pageFor;

  const SettingsPaneNavigator({
    super.key,
    required this.sectionId,
    required this.queryParam,
    required this.hub,
    required this.pageFor,
  });

  /// The page [pageFor] shows for [location], or null when [location] is not
  /// under `/settings/` or names no page.
  static Widget? pageAt(String location, Widget? Function(Uri) pageFor) {
    if (!location.startsWith(_root)) return null;
    final uri = Uri.tryParse(location);
    return uri == null ? null : pageFor(uri);
  }

  /// The pages [uri] opens in a pane reading [queryParam], outermost first,
  /// each once, keeping only those [pageFor] can show.
  static List<(String, Widget)> stackIn(
    Uri uri,
    String queryParam,
    Widget? Function(Uri) pageFor,
  ) {
    final stack = <(String, Widget)>[];
    for (final path in uri.queryParametersAll[queryParam] ?? const <String>[]) {
      final location = '$_root$path';
      if (stack.any((entry) => entry.$1 == location)) continue;
      final page = pageAt(location, pageFor);
      if (page != null) stack.add((location, page));
    }
    return stack;
  }

  @override
  State<SettingsPaneNavigator> createState() => _SettingsPaneNavigatorState();
}

const _root = '/settings/';

class _SettingsPaneNavigatorState extends State<SettingsPaneNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Opens awaiting their page's close, by location.
  final _waiting = <String, Completer<void>>{};

  /// The open pages: as last built, or as last sent to the URL when that is
  /// newer, so two opens in one frame see each other.
  List<String> _stack = const [];

  bool canShow(String location) =>
      SettingsPaneNavigator.pageAt(location, widget.pageFor) != null;

  void _go(List<String> stack) {
    _settle(stack);
    _stack = stack;
    final uri = GoRouterState.of(context).uri;
    context.goInPlace(
      Uri(
        path: uri.path,
        queryParameters: {
          'selected': widget.sectionId,
          if (stack.isNotEmpty)
            widget.queryParam: [
              for (final location in stack) location.substring(_root.length),
            ],
        },
      ).toString(),
    );
  }

  Future<void> open(String location) {
    final index = _stack.indexOf(location);
    if (index >= 0) {
      // Already open: walk back to it rather than stacking a second copy, and
      // wait on it like the open that put it there.
      if (index < _stack.length - 1) _go(_stack.sublist(0, index + 1));
      return _waiting[location]?.future ?? Future.value();
    }
    final completer = _waiting.putIfAbsent(location, Completer<void>.new);
    _go([..._stack, location]);
    return completer.future;
  }

  void replaceTop(String location) {
    if (_stack.isEmpty) {
      unawaited(open(location));
      return;
    }
    final below = _stack.sublist(0, _stack.length - 1);
    _go([...below.where((l) => l != location), location]);
  }

  /// Completes the opens whose page is no longer in [stack], whether the URL
  /// or this pane removed it. Deferred to after the frame so the awaiting code
  /// does not run during build.
  void _settle(List<String> stack) {
    final closed = [
      for (final location in _waiting.keys)
        if (!stack.contains(location)) location,
    ];
    if (closed.isEmpty) return;
    final completers = [for (final l in closed) _waiting.remove(l)!];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final completer in completers) {
        completer.complete();
      }
    });
  }

  @override
  void dispose() {
    for (final completer in _waiting.values) {
      completer.complete();
    }
    _waiting.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = SettingsPaneNavigator.stackIn(
      GoRouterState.of(context).uri,
      widget.queryParam,
      widget.pageFor,
    );
    final stack = [for (final (location, _) in pages) location];
    _settle(stack);
    _stack = stack;

    return NavigatorPopHandler(
      // A system back (Android, iPadOS) closes the top pane page first.
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: _SettingsPaneScope(
        pane: this,
        child: Navigator(
          key: _navigatorKey,
          pages: [
            MaterialPage<void>(
              key: ValueKey('${widget.sectionId}-hub'),
              child: widget.hub,
            ),
            for (final (location, page) in pages)
              MaterialPage<void>(key: ValueKey(location), child: page),
          ],
          // Back or Navigator.pop closed a page: drop it, and every page above
          // it, from the URL so the next build does not reopen it.
          onDidRemovePage: (page) {
            final index = _stack.indexWhere((l) => ValueKey(l) == page.key);
            if (index >= 0) _go(_stack.sublist(0, index));
          },
        ),
      ),
    );
  }
}

class _SettingsPaneScope extends InheritedWidget {
  final _SettingsPaneNavigatorState pane;

  const _SettingsPaneScope({required this.pane, required super.child});

  /// The pane around [context], without depending on it: the pane is looked
  /// up when a page opens another, not when it builds.
  static _SettingsPaneNavigatorState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SettingsPaneScope>()?.pane;

  @override
  bool updateShouldNotify(_SettingsPaneScope oldWidget) =>
      pane != oldWidget.pane;
}
