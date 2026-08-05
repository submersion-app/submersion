import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BathymetryGrid grid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 2,
  cols: 3,
  depthsMeters: const [30, 60, -8, 90, null, 15],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

Widget host(TissuePick pick) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SeascapeHoverTooltip(pick: pick, grid: grid()),
    ),
  ),
);

void main() {
  testWidgets('wet cell shows coordinates and unit-formatted depth', (
    tester,
  ) async {
    // pick.col = row 1, pick.comp = col 2 -> depth 15 m.
    await tester.pumpWidget(
      host(const TissuePick(col: 1, comp: 2, screenPos: Offset.zero)),
    );
    expect(find.textContaining('12.15100'), findsOneWidget);
    expect(find.textContaining('-68.29800'), findsOneWidget);
    expect(find.textContaining('15.0m'), findsOneWidget);
  });

  testWidgets('land cell shows coordinates with an em-dash for depth', (
    tester,
  ) async {
    // row 0, col 2 -> -8 (land).
    await tester.pumpWidget(
      host(const TissuePick(col: 0, comp: 2, screenPos: Offset.zero)),
    );
    expect(find.textContaining('—'), findsOneWidget);
    expect(find.textContaining('m'), findsNothing);
  });

  testWidgets('a stale out-of-range pick renders nothing', (tester) async {
    await tester.pumpWidget(
      host(const TissuePick(col: 9, comp: 9, screenPos: Offset.zero)),
    );
    expect(find.textContaining('12.15'), findsNothing);
    expect(find.textContaining('—'), findsNothing);
  });
}
