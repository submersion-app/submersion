import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/shared/widgets/profile_photo/profile_photo_picker.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Contacts is hidden when no contactPhotoLoader is supplied', (
    tester,
  ) async {
    // allowContacts and contactPhotoLoader are separate parameters, so a
    // caller can ask for the option without supplying a way to fulfil it.
    // Offering it anyway would show a menu item that silently does nothing.
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => pickProfilePhoto(
              context: context,
              hasPhoto: false,
              allowContacts: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Choose from Contacts'), findsNothing);
  });

  testWidgets('Contacts is shown when a loader is supplied', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => pickProfilePhoto(
              context: context,
              hasPhoto: false,
              allowContacts: true,
              contactPhotoLoader: (_) async => Uint8List.fromList([1, 2, 3]),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Choose from Contacts'), findsOneWidget);
  });

  testWidgets('Remove Photo returns a removed result', (tester) async {
    ProfilePhotoResult? result;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await pickProfilePhoto(
                context: context,
                hasPhoto: true,
                allowContacts: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Remove Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, isNotNull);
    expect(result!.removed, isTrue);
    expect(result!.bytes, isNull);
  });

  testWidgets('a library pick runs through the crop dialog and returns bytes', (
    tester,
  ) async {
    // The complete happy path: source sheet, picker, crop dialog, encode.
    // Nothing else covers it end to end, because the real ImagePicker has no
    // Dart-side seam a fake can be injected through.
    final source = img.Image(width: 800, height: 600);
    img.fill(source, color: img.ColorRgb8(30, 140, 90));
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));

    ProfilePhotoResult? result;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await pickProfilePhoto(
                context: context,
                hasPhoto: false,
                allowContacts: false,
                pickImageOverride: (source) async =>
                    (bytes: bytes, name: 'pick.jpg'),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Desktop host, so the sheet offers Choose File rather than a library.
    final libraryOption = find.text('Choose File').evaluate().isNotEmpty
        ? find.text('Choose File')
        : find.text('Choose from Library');
    await tester.tap(libraryOption);

    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.text('Adjust Photo'), findsOneWidget);
    await tester.tap(find.text('Save'));

    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(result, isNotNull);
    expect(result!.removed, isFalse);
    final out = img.decodeImage(result!.bytes!)!;
    expect(out.width, out.height, reason: 'the stored photo must be square');
    expect(out.width, lessThanOrEqualTo(512));
  });

  testWidgets('a cancelled library pick returns null', (tester) async {
    ProfilePhotoResult? result;
    var completed = false;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await pickProfilePhoto(
                context: context,
                hasPhoto: false,
                allowContacts: false,
                pickImageOverride: (source) async => null,
              );
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final libraryOption = find.text('Choose File').evaluate().isNotEmpty
        ? find.text('Choose File')
        : find.text('Choose from Library');
    await tester.tap(libraryOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('Adjust Photo'), findsNothing);
  });

  testWidgets('choosing Contacts routes through the supplied loader', (
    tester,
  ) async {
    final source = img.Image(width: 400, height: 400);
    img.fill(source, color: img.ColorRgb8(200, 60, 60));
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));
    var loaderCalls = 0;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => pickProfilePhoto(
              context: context,
              hasPhoto: false,
              allowContacts: true,
              contactPhotoLoader: (_) async {
                loaderCalls++;
                return bytes;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Choose from Contacts'));
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(loaderCalls, 1);
    expect(find.text('Adjust Photo'), findsOneWidget);
  });
}
