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
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _trip = TripWithStats(
  trip: Trip(
    id: 'trip-1',
    name: 'Red Sea Explorer',
    startDate: DateTime(2025, 6, 1),
    endDate: DateTime(2025, 6, 8),
    tripType: TripType.liveaboard,
    createdAt: DateTime(2025, 6, 1),
    updatedAt: DateTime(2025, 6, 1),
  ),
  diveCount: 123,
  totalRuntime: 7 * 24 * 3600,
);

void main() {
  // Selection mode puts the checkbox ahead of the trip avatar rather than in
  // its place (issue #1717), so the subtitle loses 40px. The dive count and
  // runtime line must still fit a phone-width tile.
  for (final selecting in [false, true]) {
    testWidgets('fits a phone-width tile '
        '${selecting ? 'in' : 'outside'} selection mode', (tester) async {
      tester.view.physicalSize = const Size(353, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: TripListTile(
            tripWithStats: _trip,
            isSelectionMode: selecting,
            onCheckChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Checkbox), selecting ? findsOneWidget : findsNothing);
    });
  }
}
