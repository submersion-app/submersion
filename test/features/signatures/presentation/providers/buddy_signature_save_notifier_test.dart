import 'dart:ui' show ImageByteFormat, instantiateImageCodec;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';

import '../../../../helpers/test_database.dart';

/// Provider-level guard for issue #1358.
///
/// A plain `test` rather than `testWidgets`: `strokesToPng` finishes through
/// `Picture.toImage`, whose future the engine completes rather than a timer,
/// so it never resumes under the fake clock a widget test installs.
///
/// Nothing here is mocked below the notifier. The bug was that the insert
/// threw and the notifier swallowed it into an `AsyncValue` nobody watches,
/// so a test with a stubbed storage service would have stayed green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const diveId = 'dive-1';
  const buddyId = 'buddy-1';

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer();

    final at = DateTime.utc(2026, 1, 2).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value(diveId),
            diveDateTime: Value(at),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: const Value(buddyId),
            name: const Value('Reef Buddy'),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test(
    'saving strokes stores a signature the dive provider then reads',
    () async {
      // Nothing signed yet: this is the state behind the "Request" button.
      expect(
        await container.read(buddySignaturesForDiveProvider(diveId).future),
        isEmpty,
      );

      final strokes = <List<Offset>>[
        [
          const Offset(10, 40),
          const Offset(40, 20),
          const Offset(70, 60),
          const Offset(100, 30),
        ],
      ];

      final signature = await container
          .read(buddySignatureSaveNotifierProvider.notifier)
          .saveFromStrokes(
            diveId: diveId,
            buddyId: buddyId,
            buddyName: 'Reef Buddy',
            role: 'buddy',
            strokes: strokes,
            width: 608,
            height: 200,
          );

      // Null is what the notifier returns when the save throws, which is
      // exactly how #1358 presented: silent failure, button unchanged.
      expect(signature, isNotNull);
      expect(signature!.signerId, buddyId);
      expect(signature.imageData, isNotEmpty);

      // The notifier invalidates the read provider, so the section that watches
      // it sees the signature on the next build.
      final reread = await container.read(
        buddySignaturesForDiveProvider(diveId).future,
      );
      expect(reread, hasLength(1));
      expect(reread.single.signerId, buddyId);
      expect(reread.single.hasImage, isTrue);

      expect(
        await container.read(
          hasBuddySignedProvider((diveId: diveId, buddyId: buddyId)).future,
        ),
        isTrue,
      );
    },
  );

  // The strokes are in canvas coordinates, so the PNG has to be rendered at
  // the canvas size. A hardcoded 400x200 cropped every signature drawn on a
  // wider canvas, which is why some saved signatures came back part-blank.
  test(
    'the encoded PNG matches the canvas the strokes were drawn on',
    () async {
      final signature = await container
          .read(buddySignatureSaveNotifierProvider.notifier)
          .saveFromStrokes(
            diveId: diveId,
            buddyId: buddyId,
            buddyName: 'Reef Buddy',
            role: 'buddy',
            strokes: <List<Offset>>[
              [const Offset(10, 100), const Offset(590, 100)],
            ],
            width: 608,
            height: 200,
          );

      expect(signature, isNotNull);
      final image = await decodeImageFromList(signature!.imageData!);
      expect(image.width, 608);
      expect(image.height, 200);
    },
  );

  // A layout width is routinely fractional on a scaled display. Truncating
  // it would drop the last column and crop the signature again, so the
  // encoder rounds up.
  test('a fractional canvas width rounds up rather than truncating', () async {
    final signature = await container
        .read(buddySignatureSaveNotifierProvider.notifier)
        .saveFromStrokes(
          diveId: diveId,
          buddyId: buddyId,
          buddyName: 'Reef Buddy',
          role: 'buddy',
          strokes: <List<Offset>>[
            [const Offset(10, 100), const Offset(607, 100)],
          ],
          width: 607.5,
          height: 199.25,
        );

    expect(signature, isNotNull);
    final image = await decodeImageFromList(signature!.imageData!);
    expect(image.width, 608);
    expect(image.height, 200);
  });

  // An opaque background has to reach the edge of the image it is filling.
  // Filling only to the fractional request left the last column and row
  // transparent on a rounded-up bitmap, so an instructor signature (which
  // asks for a white background) came out with a transparent strip.
  test(
    'an opaque background fills the rounded-up bitmap to its edge',
    () async {
      final bytes = await SignatureStorageService.strokesToPng(
        strokes: const <List<Offset>>[
          [Offset(10, 100), Offset(400, 100)],
        ],
        width: 607.5,
        height: 199.25,
        strokeColor: const Color(0xFF000000),
        strokeWidth: 3,
        backgroundColor: const Color(0xFFFFFFFF),
      );

      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, 608);
      expect(image.height, 200);

      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      int alphaAt(int x, int y) =>
          data!.getUint8((y * image.width + x) * 4 + 3);

      // The bottom-right pixel is the one the fractional fill used to miss.
      expect(alphaAt(image.width - 1, image.height - 1), 255);
      expect(alphaAt(image.width - 1, 0), 255);
      expect(alphaAt(0, image.height - 1), 255);
    },
  );
}
