import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _dpr = 2.0;
const _captureKey = ValueKey('capture');

final _dive = Dive(
  id: 'edge-dive',
  diveNumber: 1,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  entryTime: DateTime(2026, 5, 22, 9, 14),
  exitTime: DateTime(2026, 5, 22, 9, 52),
  maxDepth: 30.0,
  entryLocation: const GeoPoint(12.34567, 98.76543),
  exitLocation: const GeoPoint(12.34612, 98.76489),
);

Future<void> _pump(WidgetTester tester) async {
  final overrides = await getBaseOverrides();
  // Only the header map matters here; keep the Surface GPS map out of the way.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(DiveDetailUiKeys.surfaceGpsSectionExpanded, false);
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(_dive.id).overrideWith((ref) async => _dive),
          diveDataSourcesProvider(
            _dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Dark card over the map's light background makes any map pixel
          // that escapes the gradient at the card's bottom edge stand out.
          theme: ThemeData(brightness: Brightness.dark),
          home: DiveDetailPage(diveId: _dive.id, embedded: true),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

double _luma(ByteData rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return 0.2126 * rgba.getUint8(i) +
      0.7152 * rgba.getUint8(i + 1) +
      0.0722 * rgba.getUint8(i + 2);
}

/// Brightest pixel on physical row [y] between [x0] and [x1].
double _rowMax(ByteData rgba, int width, int y, int x0, int x1) {
  var best = 0.0;
  for (var x = x0; x < x1; x++) {
    final l = _luma(rgba, width, x, y);
    if (l > best) best = l;
  }
  return best;
}

typedef _Frame = ({ByteData rgba, int width, Rect card, int x0, int x1});

/// Captures the current frame along with the header card's rect and the
/// physical column range to sample (clear of the rounded corners).
Future<_Frame> _capture(WidgetTester tester) async {
  final card = find.ancestor(
    of: find.byType(DiveLocationsMap),
    matching: find.byType(Card),
  );
  final rect = tester.getRect(
    find.descendant(of: card, matching: find.byType(Material)).first,
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = (await tester.runAsync(
    () => boundary.toImage(pixelRatio: _dpr),
  ))!;
  final rgba = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final width = image.width;
  image.dispose();
  return (
    rgba: rgba,
    width: width,
    card: rect,
    x0: (rect.left * _dpr).ceil() + 40,
    x1: (rect.right * _dpr).floor() - 40,
  );
}

/// Average brightness of the map near the top of the header card, where the
/// fade is at its most transparent and the header content has not started.
Future<double> _mapBrightness(WidgetTester tester) async {
  final f = await _capture(tester);
  final y = ((f.card.top + 8) * _dpr).floor();
  var sum = 0.0;
  for (var x = f.x0; x < f.x1; x++) {
    sum += _luma(f.rgba, f.width, x, y);
  }
  return sum / (f.x1 - f.x0);
}

/// Captures the frame and returns how much brighter the header card's bottom
/// edge rows are than the opaque gradient just inside the card and the page
/// just below it. Anything above zero is map content that escaped the overlay.
Future<({double excess, double bottom})> _bottomEdgeExcess(
  WidgetTester tester,
) async {
  final f = await _capture(tester);
  final rgba = f.rgba;
  final width = f.width;
  final x0 = f.x0;
  final x1 = f.x1;
  final bottom = f.card.bottom * _dpr;
  final edgeRow = bottom.floor();
  final inside = _rowMax(rgba, width, edgeRow - 4, x0, x1);
  final below = _rowMax(rgba, width, edgeRow + 4, x0, x1);
  final reference = inside > below ? inside : below;
  var excess = 0.0;
  for (final y in [edgeRow - 1, edgeRow]) {
    final e = _rowMax(rgba, width, y, x0, x1) - reference;
    if (e > excess) excess = e;
  }
  return (excess: excess, bottom: bottom);
}

void main() {
  testWidgets(
    'header map never shows through the card bottom edge during an '
    'overscroll bounce',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      // Frame capture runs real async work, which lets flutter_map's built-in
      // tile cache ask path_provider for a directory.
      final cacheDir = Directory.systemTemp.createTempSync('header_edge_');
      addTearDown(() => cacheDir.deleteSync(recursive: true));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(channel, (_) async => cacheDir.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(700 * _dpr, 700 * _dpr);
      addTearDown(tester.view.reset);

      await _pump(tester);
      expect(find.byType(DiveLocationsMap), findsOneWidget);

      // The leak is only detectable if there is bright map content to leak.
      // No tiles load under flutter_test (every HTTP request gets a 400), so
      // what shows is FlutterMap's own light background. Pin that here: a map
      // that rendered nothing, or something dark, would otherwise let a
      // leaking header pass with nothing to see.
      expect(
        await _mapBrightness(tester),
        greaterThan(100),
        reason: 'the header map must be visibly bright under the fade',
      );

      final samples = <String>[];
      var worst = 0.0;
      Future<void> sample(String phase) async {
        final r = await _bottomEdgeExcess(tester);
        samples.add(
          '$phase bottom=${r.bottom.toStringAsFixed(2)} '
          'excess=${r.excess.toStringAsFixed(1)}',
        );
        if (r.excess > worst) worst = r.excess;
      }

      await sample('rest');

      // Pull the page down past its top edge. BouncingScrollPhysics applies
      // friction to each move, so the header lands on sub-pixel offsets.
      // Start on the header card itself: the decorative map claims no drags,
      // whereas the profile chart below it would win the gesture arena.
      final start =
          tester.getTopLeft(find.byType(DiveLocationsMap)) +
          const Offset(40, 40);
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 9.3));
        await tester.pump(const Duration(milliseconds: 16));
        await sample('drag$i');
      }
      await gesture.up();

      // The ballistic spring back to the top.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await sample('spring$i');
      }
      await tester.pumpAndSettle();

      expect(
        worst,
        lessThan(12),
        reason:
            'map content leaked below the header gradient:\n'
            '${samples.join('\n')}',
      );
    },
  );
}
