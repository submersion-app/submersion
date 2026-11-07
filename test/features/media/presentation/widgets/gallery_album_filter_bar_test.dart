import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/gallery_album_filter.dart';
import 'package:submersion/features/media/presentation/widgets/gallery_album_filter_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _goPro = GalleryAlbumOption(name: 'GoPro', count: 3);
const _whatsApp = GalleryAlbumOption(name: 'WhatsApp Images', count: 2);

Widget _host({
  required List<GalleryAlbumOption> options,
  required int totalCount,
  String? selectedAlbum,
  ValueChanged<String?>? onSelected,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: GalleryAlbumFilterBar(
        options: options,
        totalCount: totalCount,
        selectedAlbum: selectedAlbum,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

ChoiceChip _chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

void main() {
  testWidgets('offers every album with its count, after All albums', (
    tester,
  ) async {
    await tester.pumpWidget(_host(options: [_goPro, _whatsApp], totalCount: 5));

    expect(find.text('All albums (5)'), findsOneWidget);
    expect(find.text('GoPro (3)'), findsOneWidget);
    expect(find.text('WhatsApp Images (2)'), findsOneWidget);
    expect(_chip(tester, 'All albums (5)').selected, isTrue);
    expect(_chip(tester, 'GoPro (3)').selected, isFalse);
    expect(
      tester.getTopLeft(find.text('All albums (5)')).dx,
      lessThan(tester.getTopLeft(find.text('GoPro (3)')).dx),
    );
  });

  testWidgets('marks the chosen album', (tester) async {
    await tester.pumpWidget(
      _host(
        options: [_goPro, _whatsApp],
        totalCount: 5,
        selectedAlbum: 'WhatsApp Images',
      ),
    );

    expect(_chip(tester, 'All albums (5)').selected, isFalse);
    expect(_chip(tester, 'WhatsApp Images (2)').selected, isTrue);
  });

  testWidgets('reports the album tapped, and null for All albums', (
    tester,
  ) async {
    final picked = <String?>[];
    await tester.pumpWidget(
      _host(
        options: [_goPro, _whatsApp],
        totalCount: 5,
        selectedAlbum: 'GoPro',
        onSelected: picked.add,
      ),
    );

    await tester.tap(find.text('WhatsApp Images (2)'));
    await tester.tap(find.text('All albums (5)'));

    expect(picked, ['WhatsApp Images', null]);
  });

  testWidgets('is absent when no album would narrow the photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        options: const [GalleryAlbumOption(name: 'Camera', count: 4)],
        totalCount: 4,
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('is shown for one album that holds only some photos', (
    tester,
  ) async {
    await tester.pumpWidget(_host(options: [_goPro], totalCount: 5));

    expect(find.text('GoPro (3)'), findsOneWidget);
  });

  testWidgets('names the row for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(options: [_goPro, _whatsApp], totalCount: 5));

    expect(find.bySemanticsLabel('Filter by album'), findsOneWidget);
    semantics.dispose();
  });
}
