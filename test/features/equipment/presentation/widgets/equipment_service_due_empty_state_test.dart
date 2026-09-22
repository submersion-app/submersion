import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The empty state a severity filter lands on when nothing is in that bucket.
///
/// The severities come from the home strip's service chips, and the strip only
/// shows a chip for a bucket that has something in it -- so these are the
/// states a diver reaches by narrowing the list themselves, or by coming back
/// after servicing the gear the chip counted.
Future<void> _pumpFiltered(
  WidgetTester tester,
  ServiceDueFilter severity,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        activeEquipmentProvider.overrideWith(
          (ref) async => const <EquipmentItem>[],
        ),
        allEquipmentProvider.overrideWith(
          (ref) async => const <EquipmentItem>[],
        ),
        serviceDueEquipmentProvider.overrideWith(
          (ref, _) async => const <EquipmentItem>[],
        ),
        equipmentListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
        equipmentFilterProvider.overrideWith(
          (ref) => EquipmentFilterState(serviceDue: severity),
        ),
      ],
      child: const EquipmentListContent(showAppBar: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('service-due empty state', () {
    testWidgets('names the severity it looked for', (tester) async {
      await _pumpFiltered(tester, ServiceDueFilter.overdue);
      expect(find.text('No equipment overdue for service'), findsOneWidget);
    });

    testWidgets('due soon names its own severity', (tester) async {
      await _pumpFiltered(tester, ServiceDueFilter.dueSoon);
      expect(find.text('No equipment due for service soon'), findsOneWidget);
    });

    testWidgets('an empty due-soon list does not claim the kit is up to '
        'date', (tester) async {
      // Nothing due soon says nothing about what has already lapsed, so the
      // celebratory line would be a claim the list cannot support.
      await _pumpFiltered(tester, ServiceDueFilter.dueSoon);
      expect(
        find.text('All your equipment is up to date on service!'),
        findsNothing,
      );
      expect(find.text('Nothing is due for service soon.'), findsOneWidget);
    });

    testWidgets('an empty overdue list says only that nothing has lapsed', (
      tester,
    ) async {
      await _pumpFiltered(tester, ServiceDueFilter.overdue);
      expect(
        find.text('All your equipment is up to date on service!'),
        findsNothing,
      );
      expect(find.text('Nothing is overdue for service.'), findsOneWidget);
    });

    testWidgets('the combined filter keeps its celebratory line', (
      tester,
    ) async {
      // With both buckets empty, nothing is due at all, so the claim holds.
      await _pumpFiltered(tester, ServiceDueFilter.any);
      expect(
        find.text('All your equipment is up to date on service!'),
        findsOneWidget,
      );
    });
  });
}
