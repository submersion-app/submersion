import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/router/shortcut_locations.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

void main() {
  test('catalog ids are unique and never collide with built-ins', () {
    final ids = kNavShortcuts.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(kNavShortcuts.length, 39);
    for (final id in kNavShortcutOrderIds) {
      expect(movableNavIds, isNot(contains(id)));
    }
  });

  test('every planning shortcut is gated, nothing else is', () {
    for (final s in kNavShortcuts) {
      expect(
        s.isPlanning,
        s.canonicalPath.startsWith('/planning'),
        reason: s.id,
      );
    }
  });

  test('every shortcut borrows the accent of a real nav destination', () {
    // Matched against each destination's accent, not its id: Training wears
    // the Certifications accent, which the card wallet shortcut borrows.
    final builtIns = kNavDestinations.map((d) => d.accentId).toSet();
    for (final s in kNavShortcuts) {
      expect(builtIns, contains(s.accent), reason: s.id);
    }
  });

  test('order ids round-trip through the prefix', () {
    expect(navShortcutOrderId('gas-blender'), 'shortcut:gas-blender');
    expect(navShortcutForOrderId('shortcut:gas-blender')?.id, 'gas-blender');
    expect(navShortcutForOrderId('gas-blender'), isNull);
    expect(navShortcutForOrderId('shortcut:retired'), isNull);
  });

  test('a shortcut destination routes to its alias and owns its page', () {
    final d = navShortcutDestination(navShortcutById('gas-blender')!);
    expect(d.id, 'shortcut:gas-blender');
    expect(d.route, shortcutLocation('gas-blender'));
    expect(d.extraMatchPaths, ['/planning/gas-calculators/blender']);
    expect(d.selection?.queryKey, 'calc');
    expect(d.selection?.queryValue, 'blender');
    expect(d.accentId, 'planning');
  });

  test('resolveNavDestination finds built-ins and shortcuts', () {
    final byId = {for (final d in kNavDestinations) d.id: d};
    expect(resolveNavDestination('dives', byId)?.route, '/dives');
    expect(
      resolveNavDestination('shortcut:insights-gas', byId)?.route,
      '/shortcut/insights-gas',
    );
    expect(resolveNavDestination('shortcut:nope', byId), isNull);
  });

  group('nav labels', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('a long page name gets a short nav label', () {
      final blender = navShortcutById('gas-blender')!;
      expect(blender.label(l10n), 'Trimix blender');
      expect(navShortcutDestination(blender).label(l10n), 'Blender');
    });

    test('no shortcut shares a name with a built-in destination', () {
      final builtIns = kNavDestinations.map((d) => d.label(l10n)).toSet();
      for (final s in kNavShortcuts) {
        expect(
          builtIns,
          isNot(contains(navShortcutDestination(s).label(l10n))),
          reason: s.id,
        );
      }
    });

    test('a page name that already fits is the nav label', () {
      final records = navShortcutById('records')!;
      expect(navShortcutDestination(records).label(l10n), 'Records');
    });

    test('the backup shortcut uses the Backups page name (#3482)', () {
      final backup = navShortcutById('backup')!;
      expect(backup.label(l10n), 'Backups');
    });

    test('the long names all have a short nav label', () {
      const long = {
        'deco-calculator',
        'gas-calculators',
        'weight-calculator',
        'surface-interval',
        'gas-blender',
        'insights-gas',
        'insights-time-patterns',
        'insights-profile',
        'dive-activity-map',
        'dive-centers-map',
        'equipment-sets',
        'certification-wallet',
        'emergency-card',
        'backup',
      };
      for (final id in long) {
        final s = navShortcutById(id)!;
        expect(s.navLabel, isNotNull, reason: id);
        expect(
          s.navLabel!(l10n).length,
          lessThan(s.label(l10n).length),
          reason: id,
        );
      }
    });
  });
}
