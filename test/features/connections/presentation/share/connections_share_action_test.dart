import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_action.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_file_picker_platform.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required Future<Uint8List> Function() render,
    List<String>? shared,
    List<String>? saved,
    String? saveResult = 'x',
    bool defaultSave = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => shareConnectionsImage(
                context,
                render: render,
                now: DateTime(2026, 10, 5),
                share: (bytes, name, origin) async => shared?.add(name),
                save: defaultSave
                    ? null
                    : (bytes, name) async {
                        saved?.add(name);
                        return saveResult;
                      },
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('share hands the PNG to the share sheet with a dated name', (
    tester,
  ) async {
    final shared = <String>[];
    await open(tester, render: () async => Uint8List(4), shared: shared);
    expect(find.text('Share map image'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(shared, ['submersion-connections-20261005.png']);
  });

  testWidgets('save writes the file; a cancelled save says nothing', (
    tester,
  ) async {
    final saved = <String>[];
    await open(
      tester,
      render: () async => Uint8List(4),
      saved: saved,
      saveResult: null,
    );
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();
    expect(saved, ['submersion-connections-20261005.png']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('dismissing the sheet renders nothing', (tester) async {
    var rendered = 0;
    await open(
      tester,
      render: () async {
        rendered++;
        return Uint8List(4);
      },
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(rendered, 0);
  });

  testWidgets('a render failure shows a snackbar', (tester) async {
    await open(tester, render: () async => throw StateError('boom'));
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't create the image"), findsOneWidget);
  });

  test('the file name is dated', () {
    expect(
      connectionsShareFileName(DateTime(2026, 1, 9)),
      'submersion-connections-20260109.png',
    );
  });
  testWidgets('the save panel is titled for the map, not a dive profile', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    final picker = MockFilePickerPlatform()..saveFileResult = null;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = original);
    await open(tester, render: () async => Uint8List(4), defaultSave: true);
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();
    expect(picker.lastSavedDialogTitle, 'Save map image');
    expect(picker.lastSavedFileName, 'submersion-connections-20261005.png');
  });
  testWidgets('the iPad popover points at the share button, not the page', (
    tester,
  ) async {
    Rect? origin;
    late BuildContext page;
    late BuildContext button;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (pageContext) {
              page = pageContext;
              return Align(
                alignment: Alignment.topRight,
                child: Builder(
                  builder: (buttonContext) {
                    button = buttonContext;
                    return const SizedBox(width: 40, height: 40);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    final future = shareConnectionsImage(
      page,
      anchorContext: button,
      render: () async => Uint8List(4),
      share: (bytes, name, o) async => origin = o,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await future;
    expect(origin, tester.getRect(find.byType(SizedBox).last));
  });
  testWidgets('a completed save says so', (tester) async {
    await open(tester, render: () async => Uint8List(4), saveResult: '/x.png');
    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();
    expect(find.text('Image saved'), findsOneWidget);
  });
}
