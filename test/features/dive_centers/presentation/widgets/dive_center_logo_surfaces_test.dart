import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A dive center's logo in every list, the picker and the map (#4460).
Uint8List _jpeg() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(0, 90, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

final _logo = _jpeg();

DiveCenter _center({Uint8List? logo, bool closed = false}) {
  final now = DateTime(2026);
  return DiveCenter(
    id: 'c1',
    name: 'Toucan Diving',
    city: 'Kralendijk',
    latitude: 12.15,
    longitude: -68.28,
    isPermanentlyClosed: closed,
    logo: logo,
    createdAt: now,
    updatedAt: now,
  );
}

/// The avatar drawing [logo], whatever its shape.
Finder _avatarWith(Uint8List? logo) => find.byWidgetPredicate(
  (w) => w is DiveCenterAvatar && identical(w.logo, logo),
);

class _ListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _ListNotifier(List<DiveCenter> centers) : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('list tiles', () {
    final tiles = <String, Widget Function(DiveCenter)>{
      'detailed': (c) => DiveCenterListTile(center: c),
      'compact': (c) => CompactDiveCenterListTile(center: c, diveCount: 3),
      'dense': (c) => DenseDiveCenterListTile(center: c, diveCount: 3),
    };

    Future<void> pumpTile(WidgetTester tester, Widget tile) async {
      await tester.pumpWidget(
        testApp(
          overrides: [diveCenterDiveCountProvider.overrideWith((ref, id) => 3)],
          child: tile,
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final entry in tiles.entries) {
      testWidgets('${entry.key} tile shows the center logo', (tester) async {
        await pumpTile(tester, entry.value(_center(logo: _logo)));
        expect(_avatarWith(_logo), findsOneWidget);
      });
    }

    testWidgets('the detailed tile keeps its store icon with no logo', (
      tester,
    ) async {
      await pumpTile(tester, tiles['detailed']!(_center()));
      expect(find.byIcon(Icons.store), findsOneWidget);
    });

    for (final name in ['compact', 'dense']) {
      testWidgets('the $name tile adds nothing with no logo', (tester) async {
        await pumpTile(tester, tiles[name]!(_center()));
        expect(find.byType(DiveCenterAvatar), findsNothing);
        expect(find.byIcon(Icons.store), findsNothing);
      });
    }
  });

  testWidgets('a picker row shows the center logo', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          allDiveCentersProvider.overrideWith(
            (ref) async => [_center(logo: _logo)],
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: DiveCenterPickerSheet(
          scrollController: ScrollController(),
          selectedCenter: null,
          onCenterSelected: (_) {},
          onCreateNewCenter: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_avatarWith(_logo), findsOneWidget);
  });

  group('map', () {
    Future<void> pumpMap(
      WidgetTester tester,
      DiveCenter center, {
      bool selected = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            diveCenterListNotifierProvider.overrideWith(
              (ref) => _ListNotifier([center]),
            ),
            diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveCenterMapContent(
                selectedId: selected ? center.id : null,
                onItemSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the marker and the info card show the center logo', (
      tester,
    ) async {
      await pumpMap(tester, _center(logo: _logo));
      // The marker (and its world-wrapped copies) plus the info card.
      expect(_avatarWith(_logo), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.store), findsNothing);
    });

    testWidgets('a marker logo leaves a band of the rating colour', (
      tester,
    ) async {
      // Selected: a 50 px marker with a 2 px white border, 46 px of fill.
      await pumpMap(tester, _center(logo: _logo));
      final marker = find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Dive center: Toucan Diving',
        ),
        matching: find.byType(DiveCenterMarkerGlyph),
      );
      final glyph = tester.getSize(marker.first);
      // At least 3 px of the fill shows on every side of the logo.
      expect(glyph.width, lessThanOrEqualTo(46 - 6));
    });

    testWidgets('a closed center with a logo is still drawn faded', (
      tester,
    ) async {
      // A selected marker is never faded, so this one is left unselected.
      await pumpMap(
        tester,
        _center(logo: _logo, closed: true),
        selected: false,
      );

      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == kClosedDiveCenterOpacity,
          ),
          matching: _avatarWith(_logo),
        ),
        findsWidgets,
      );
    });
  });
}
