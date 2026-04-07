import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _MockEquipmentListNotifier
    extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _MockEquipmentListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockEquipmentSetListNotifier
    extends StateNotifier<AsyncValue<List<EquipmentSet>>>
    implements EquipmentSetListNotifier {
  _MockEquipmentSetListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<List<Override>> _buildOverrides({
  List<EquipmentItem> equipment = const [],
  bool loading = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    equipmentListNotifierProvider.overrideWith(
      (ref) => _MockEquipmentListNotifier(
        loading ? const AsyncValue.loading() : AsyncValue.data(equipment),
      ),
    ),
    equipmentSetListNotifierProvider.overrideWith(
      (ref) => _MockEquipmentSetListNotifier(
        const AsyncValue.data(<EquipmentSet>[]),
      ),
    ),
    equipmentListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
  ];
}

void main() {
  group('EquipmentListPage', () {
    testWidgets('shows Equipment title in app bar', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Equipment'), findsWidgets);
    });

    testWidgets('shows Equipment and Sets tabs', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Equipment'), findsWidgets);
      expect(find.text('Sets'), findsOneWidget);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides(loading: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentListPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows Add Equipment FAB on equipment tab', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EquipmentListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Equipment'), findsOneWidget);
    });
  });
}
