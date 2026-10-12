import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_selection.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

NavDestination _d(
  String id,
  String route, {
  List<String> extra = const [],
  NavSelectionMatch? selection,
}) => NavDestination(
  id: id,
  route: route,
  icon: Icons.circle,
  selectedIcon: Icons.circle,
  label: (_) => id,
  extraMatchPaths: extra,
  selection: selection,
);

final _home = _d('dashboard', '/dashboard');
final _more = _d('more', '');
final _planning = _d('planning', '/planning');
final _dives = _d('dives', '/dives');
final _blender = _d(
  'shortcut:gas-blender',
  '/shortcut/gas-blender',
  extra: ['/planning/gas-calculators/blender'],
  selection: const NavSelectionMatch(
    path: '/planning/gas-calculators',
    queryKey: 'calc',
    queryValue: 'blender',
  ),
);
final _deco = _d(
  'shortcut:deco-calculator',
  '/shortcut/deco-calculator',
  extra: ['/planning/deco-calculator'],
  selection: const NavSelectionMatch(
    path: '/planning',
    queryKey: 'tool',
    queryValue: 'deco-calculator',
  ),
);

void main() {
  group('navMatchScore', () {
    test('a path prefix scores its segment count', () {
      expect(navMatchScore(_dives, Uri.parse('/dives/42')), 1);
    });

    test('a prefix must end on a segment boundary', () {
      expect(navMatchScore(_dives, Uri.parse('/dives-x')), 0);
    });

    test('the empty More route never matches', () {
      expect(navMatchScore(_more, Uri.parse('/anything')), 0);
    });

    test('a canonical path outscores its section', () {
      final uri = Uri.parse('/planning/gas-calculators/blender/invoices');
      expect(
        navMatchScore(_blender, uri),
        greaterThan(navMatchScore(_planning, uri)),
      );
    });

    test('a desktop selection form outscores the hub it rides on', () {
      final uri = Uri.parse('/planning?tool=deco-calculator');
      expect(navMatchScore(_planning, uri), 1);
      expect(navMatchScore(_deco, uri), 2);
    });

    test('a different selection value does not match', () {
      expect(navMatchScore(_deco, Uri.parse('/planning?tool=no-fly')), 0);
    });

    test('the desktop selection form of a gas calculator matches it', () {
      final uri = Uri.parse('/planning/gas-calculators?calc=blender');
      expect(navMatchScore(_blender, uri), 3);
    });
  });

  group('railSelectedIndex', () {
    test('the shortcut wins over its section', () {
      final rail = [_home, _planning, _blender];
      expect(
        railSelectedIndex(rail, Uri.parse('/planning/gas-calculators/blender')),
        2,
      );
      expect(railSelectedIndex(rail, Uri.parse('/planning/no-fly')), 1);
    });

    test('the alias location selects the shortcut', () {
      expect(
        railSelectedIndex([
          _home,
          _blender,
        ], Uri.parse('/shortcut/gas-blender')),
        1,
      );
    });

    test('no match selects Home', () {
      expect(railSelectedIndex([_home, _dives], Uri.parse('/nowhere')), 0);
    });
  });

  group('phoneSelectedIndex', () {
    test('a shortcut in the bar beats its section in More', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _blender, _dives, _more],
          overflow: [_planning],
          location: Uri.parse('/planning/gas-calculators/blender'),
        ),
        1,
      );
    });

    test('a shortcut in More beats its section in the bar, selecting More', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _planning, _dives, _more],
          overflow: [_blender],
          location: Uri.parse('/planning/gas-calculators/blender'),
        ),
        3,
      );
    });

    test('a section in the bar is selected on its own pages', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _planning, _dives, _more],
          overflow: [_blender],
          location: Uri.parse('/planning/no-fly'),
        ),
        1,
      );
    });

    test('no match selects More', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _dives, _more],
          overflow: const [],
          location: Uri.parse('/settings'),
        ),
        2,
      );
    });
  });

  group('alias locations', () {
    NavDestination shortcut(String id) =>
        navShortcutDestination(navShortcutById(id)!);

    test(
      'without its shortcut on the surface, the page selects its section',
      () {
        expect(
          railSelectedIndex([
            _home,
            _dives,
            _planning,
          ], Uri.parse('/shortcut/gas-blender')),
          2,
        );
        expect(
          phoneSelectedIndex(
            primary: [_home, _planning, _dives, _more],
            overflow: const [],
            location: Uri.parse('/shortcut/insights-gas'),
          ),
          3, // Insights is not on this surface either: More.
        );
      },
    );

    test('the hub opened as a shortcut selects a calculator shortcut', () {
      final rail = [
        _home,
        shortcut('gas-calculators'),
        shortcut('gas-blender'),
      ];
      expect(
        railSelectedIndex(
          rail,
          Uri.parse('/shortcut/gas-calculators?calc=blender'),
        ),
        2,
      );
      expect(
        railSelectedIndex(rail, Uri.parse('/shortcut/gas-calculators')),
        1,
      );
    });

    test('an unknown alias matches nothing but itself', () {
      expect(
        railSelectedIndex([_home, _planning], Uri.parse('/shortcut/retired')),
        0,
      );
    });
  });
}
