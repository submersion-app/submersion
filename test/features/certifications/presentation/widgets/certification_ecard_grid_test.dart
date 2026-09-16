import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_grid.dart';

import '../../../../helpers/test_app.dart';

/// A valid 1x1 transparent PNG, so the image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

final _now = DateTime(2026, 8, 9);

Certification _makeCert({
  String id = 'cert-1',
  String name = 'Open Water Diver',
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level,
  Uint8List? photoFront,
  Uint8List? photoBack,
}) {
  return Certification(
    id: id,
    name: name,
    agency: agency,
    level: level,
    photoFront: photoFront,
    photoBack: photoBack,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required List<Certification> certifications,
  String diverName = 'Eric Griffin',
  ValueChanged<Certification>? onCardLongPress,
  ValueChanged<Certification>? onShare,
  ValueChanged<Certification>? onMoreOptions,
  double width = 400,
  double height = 800,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    testApp(
      locale: locale,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: CertificationEcardGrid(
          certifications: certifications,
          diverName: diverName,
          onCardLongPress: onCardLongPress,
          onShare: onShare,
          onMoreOptions: onMoreOptions,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CertificationEcardGrid layout', () {
    testWidgets('lays out cards in a vertically scrolling grid, not a '
        'horizontal page view', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(id: 'cert-1'),
          _makeCert(id: 'cert-2', agency: CertificationAgency.ssi),
        ],
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(PageView), findsNothing);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(gridView.scrollDirection, Axis.vertical);
    });

    testWidgets('renders every certification as a card', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(id: 'cert-1'),
          _makeCert(id: 'cert-2', agency: CertificationAgency.ssi),
          _makeCert(id: 'cert-3', agency: CertificationAgency.naui),
        ],
      );

      expect(find.byType(CertificationEcard), findsNWidgets(3));
    });

    testWidgets('shows a single column on a phone-width viewport', (
      tester,
    ) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(id: 'cert-1'),
          _makeCert(id: 'cert-2'),
        ],
        width: 360,
        height: 900,
      );

      final delegate =
          tester.widget<GridView>(find.byType(GridView)).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
    });

    testWidgets('adds columns as the viewport widens, capped so no card '
        'exceeds the maximum card width', (tester) async {
      await _pumpGrid(
        tester,
        certifications: List.generate(6, (i) => _makeCert(id: 'cert-$i')),
        width: 1300,
        height: 900,
      );

      final delegate =
          tester.widget<GridView>(find.byType(GridView)).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, greaterThanOrEqualTo(2));
    });

    testWidgets('shows the empty state and no grid when there are no '
        'certifications', (tester) async {
      await _pumpGrid(tester, certifications: []);

      expect(find.byType(GridView), findsNothing);
      expect(find.text('No certifications yet'), findsOneWidget);
    });
  });

  group('CertificationEcardGrid flip on tap', () {
    testWidgets('tapping a card flips it to show the back', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [_makeCert(id: 'cert-1', photoBack: _onePixelPng)],
      );

      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('front')),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(CertificationEcard));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('front')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('back')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a flipped card a second time shows the front '
        'again', (tester) async {
      await _pumpGrid(tester, certifications: [_makeCert(id: 'cert-1')]);

      await tester.tap(find.byType(CertificationEcard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CertificationEcard));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('front')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('flip state is keyed by certification id, so it survives '
        'a new list instance for the same certifications', (tester) async {
      final cert = _makeCert(id: 'cert-1');

      await _pumpGrid(tester, certifications: [cert]);
      await tester.tap(find.byType(CertificationEcard));
      await tester.pumpAndSettle();

      // A freshly-fetched list with an equal-but-distinct instance, as the
      // provider would hand back after a reload.
      await _pumpGrid(tester, certifications: [_makeCert(id: 'cert-1')]);

      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('back')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('flipping one card does not flip the others', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(id: 'cert-1'),
          _makeCert(id: 'cert-2'),
        ],
        width: 360,
        height: 1400,
      );

      await tester.tap(find.byType(CertificationEcard).first);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('back')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('front')),
        ),
        findsOneWidget,
      );
    });
  });

  group('CertificationEcardGrid actions', () {
    testWidgets('long-pressing a card calls onCardLongPress with that '
        'certification', (tester) async {
      Certification? pressed;
      final cert = _makeCert(id: 'cert-1');

      await _pumpGrid(
        tester,
        certifications: [cert],
        onCardLongPress: (c) => pressed = c,
      );

      await tester.longPress(find.byType(CertificationEcard));
      await tester.pump();

      expect(pressed, cert);
    });

    testWidgets('the share icon in the action row calls onShare with that '
        'certification, without flipping the card', (tester) async {
      Certification? shared;
      final cert = _makeCert(id: 'cert-1');

      await _pumpGrid(
        tester,
        certifications: [cert],
        onShare: (c) => shared = c,
      );

      await tester.tap(find.byTooltip('Share certification'));
      await tester.pump();

      expect(shared, cert);
      expect(
        find.descendant(
          of: find.byType(CertificationEcard),
          matching: find.byKey(const ValueKey('front')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the more-options icon in the action row calls '
        'onMoreOptions with that certification', (tester) async {
      Certification? more;
      final cert = _makeCert(id: 'cert-1');

      await _pumpGrid(
        tester,
        certifications: [cert],
        onMoreOptions: (c) => more = c,
      );

      await tester.tap(find.byTooltip('More options'));
      await tester.pump();

      expect(more, cert);
    });

    testWidgets('the action row shows the derived title when the stored '
        'name matches the level', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(
            id: 'cert-1',
            name: 'Open Water',
            agency: CertificationAgency.ssi,
            level: CertificationLevel.openWater,
          ),
        ],
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('actionRowTitle'))).data,
        'Open Water',
      );
    });

    testWidgets('the action row shows the custom name, not the credentials '
        'line, so the card stays identifiable', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(
            id: 'cert-1',
            name: 'Bali OW w/ Made',
            agency: CertificationAgency.padi,
            level: CertificationLevel.openWater,
          ),
        ],
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('actionRowTitle'))).data,
        'Bali OW w/ Made',
      );
    });
  });

  group('CertificationEcardGrid stress', () {
    testWidgets('a large certification list builds lazily: far fewer card '
        'widgets exist than certifications', (tester) async {
      final certifications = List.generate(
        200,
        (i) => _makeCert(id: 'cert-$i'),
      );

      await _pumpGrid(
        tester,
        certifications: certifications,
        width: 400,
        height: 800,
      );

      final builtCards = find.byType(CertificationEcard).evaluate().length;
      expect(builtCards, lessThan(20));
    });

    testWidgets('renders without overflow at 2x text scale on a narrow '
        'viewport', (tester) async {
      await _pumpGrid(
        tester,
        certifications: List.generate(4, (i) => _makeCert(id: 'cert-$i')),
        width: 320,
        height: 700,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow under a right-to-left locale', (
      tester,
    ) async {
      await _pumpGrid(
        tester,
        certifications: [
          _makeCert(id: 'cert-1'),
          _makeCert(id: 'cert-2', agency: CertificationAgency.ssi),
        ],
        width: 360,
        height: 800,
        locale: const Locale('he'),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CertificationEcard), findsNWidgets(2));
    });

    testWidgets('renders without overflow on a zero-width constraint '
        'during layout transitions', (tester) async {
      await _pumpGrid(
        tester,
        certifications: [_makeCert(id: 'cert-1')],
        width: 1,
        height: 400,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
