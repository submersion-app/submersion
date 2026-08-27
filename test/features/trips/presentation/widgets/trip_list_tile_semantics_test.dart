import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';

import '../../../../helpers/test_app.dart';

/// The tile's subtree watches [settingsProvider]; the real notifier reaches for
/// SharedPreferences, so stand in with a fixed [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.initial = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// `Override` is sealed and not re-exported, so the helper stays dynamic --
// same convention as `testApp`'s `overrides` parameter.
List<dynamic> _settingsOverrides() {
  return [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())];
}

TripWithStats _makeTrip({int diveCount = 3, int totalRuntime = 0}) {
  final start = DateTime(2025, 6, 1);
  return TripWithStats(
    trip: Trip(
      id: 'trip-1',
      name: 'Red Sea Explorer',
      startDate: start,
      endDate: start.add(const Duration(days: 7)),
      tripType: TripType.shore,
      createdAt: start,
      updatedAt: start,
    ),
    diveCount: diveCount,
    totalRuntime: totalRuntime,
  );
}

/// The merged semantics label for the single [TripListTile] in the tree.
String _label(WidgetTester tester) {
  final node = tester.getSemantics(find.byType(TripListTile));
  return node.label;
}

void main() {
  group('TripListTile semantics', () {
    testWidgets('dive count is localized, not hard-coded English', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: _settingsOverrides(),
          child: TripListTile(tripWithStats: _makeTrip(diveCount: 3)),
        ),
      );

      // A German screen reader must not hear the English word "dives".
      expect(_label(tester), contains('Tauchgänge'));
      expect(_label(tester), isNot(contains('dives')));
      handle.dispose();
    });

    testWidgets('date range needs no translated connector word', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: _settingsOverrides(),
          child: TripListTile(tripWithStats: _makeTrip()),
        ),
      );

      // The sibling compact tile already joins the two dates with a dash,
      // which reads correctly in every locale and needs no new ARB key.
      expect(_label(tester), isNot(contains(' to ')));
      handle.dispose();
    });

    testWidgets('selection is a semantics flag, not label text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _settingsOverrides(),
          child: TripListTile(tripWithStats: _makeTrip(), isSelected: true),
        ),
      );

      final node = tester.getSemantics(find.byType(TripListTile));
      expect(node, isSemantics(isSelected: true));
      expect(node.label, isNot(contains('selected')));
      handle.dispose();
    });

    testWidgets('an unselected tile does not carry the selected flag', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: _settingsOverrides(),
          child: TripListTile(tripWithStats: _makeTrip()),
        ),
      );

      final node = tester.getSemantics(find.byType(TripListTile));
      expect(node, isSemantics(isSelected: false));
      handle.dispose();
    });
  });
}
