import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/image_dimensions_reader.dart';

import '../../../../helpers/media_container_fixtures.dart';

/// A SOFn segment: [length:2][precision:1][height:2][width:2][components:1]
/// followed by 3 bytes per component.
List<int> sofSegment(int marker, int width, int height, {int components = 3}) =>
    [
      0xff,
      marker,
      ...u16(8 + 3 * components),
      8, // sample precision
      ...u16(height),
      ...u16(width),
      components,
      for (var i = 0; i < components; i++) ...[i + 1, 0x11, 0],
    ];

/// A hand-assembled JPEG: SOI, [before] segments, the frame header, then
/// [scan] standing in for the entropy-coded data.
List<int> jpegBytes({
  required int width,
  required int height,
  int sofMarker = 0xc0,
  List<int> before = const [],
  List<int> scan = const [],
}) => [
  0xff, 0xd8, // SOI
  ...before,
  ...sofSegment(sofMarker, width, height),
  if (scan.isNotEmpty) ...[
    0xff, 0xda, ...u16(8), 1, 1, 0, 0, 63, 0, // SOS header, 1 component
    ...scan,
  ],
];

/// An APPn segment of [payloadBytes] filler, to push the frame header past a
/// realistic EXIF/ICC block.
List<int> appSegment(int marker, int payloadBytes) => [
  0xff,
  marker,
  ...u16(2 + payloadBytes),
  for (var i = 0; i < payloadBytes; i++) 0x5a,
];

/// `ispe` carries the stored pixel size of one item.
List<int> ispe(int width, int height) =>
    fullBox('ispe', [...u32(width), ...u32(height)]);

/// One `ipma` entry: item [itemId] associated with the 1-based [indices] into
/// `ipco`'s child list.
List<int> ipmaEntry(int itemId, List<int> indices) => [
  ...u16(itemId),
  indices.length, // association_count
  ...indices, // essential bit clear + 7-bit property index
];

/// Minimal HEIC carrying [properties] in `meta > iprp > ipco`, associated to
/// items by [associations], with [primaryItem] named by `pitm`.
List<int> heicWithProperties({
  required List<int> properties,
  required List<List<int>> associations,
  required int primaryItem,
  bool includePitm = true,
}) {
  final ipco = box('ipco', properties);
  final ipma = fullBox('ipma', [
    ...u32(associations.length),
    for (final entry in associations) ...entry,
  ]);
  final iprp = box('iprp', [...ipco, ...ipma]);
  final pitm = fullBox('pitm', u16(primaryItem));
  return [
    ...box('ftyp', 'heic'.codeUnits),
    ...box('meta', [0, 0, 0, 0, if (includePitm) ...pitm, ...iprp]),
  ];
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_dimensions_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  File write(String name, List<int> bytes) =>
      File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

  group('JPEG', () {
    test('reads width and height from the frame header', () {
      final f = write('a.jpg', jpegBytes(width: 4032, height: 3024));

      expect(readImageDimensions(f, 'image/jpeg'), (width: 4032, height: 3024));
    });

    test('agrees with the decoder on a real encoded JPEG', () {
      final encoded = img.encodeJpg(img.Image(width: 7, height: 3));
      final f = write('real.jpg', encoded);

      // The value this reader replaces came from JpegDecoder.startDecode;
      // it must not move for any file that decoder could already read.
      final decoded = img.JpegDecoder().startDecode(encoded)!;
      expect(readImageDimensions(f, 'image/jpeg'), (
        width: decoded.width,
        height: decoded.height,
      ));
    });

    test('answers without reading the entropy-coded scan data', () {
      // The whole point: dimensions come from the SOF, so a file whose scan
      // is truncated (no EOI, no following marker) still answers. The old
      // decoder returned null here because it required an SOS *and* then
      // byte-scanned to the next marker.
      final f = write(
        'truncated.jpg',
        jpegBytes(width: 640, height: 480, scan: List.filled(200000, 0x7f)),
      );

      expect(readImageDimensions(f, 'image/jpeg'), (width: 640, height: 480));
    });

    test('skips APPn segments ahead of the frame header', () {
      final f = write(
        'exif.jpg',
        jpegBytes(
          width: 100,
          height: 50,
          before: [
            ...appSegment(0xe0, 14), // JFIF
            ...appSegment(0xe1, 60000), // a full-size EXIF block
            ...appSegment(0xe2, 5000), // ICC profile
          ],
        ),
      );

      expect(readImageDimensions(f, 'image/jpeg'), (width: 100, height: 50));
    });

    test('reads a progressive frame header (SOF2)', () {
      final f = write(
        'prog.jpg',
        jpegBytes(width: 300, height: 200, sofMarker: 0xc2),
      );

      expect(readImageDimensions(f, 'image/jpeg'), (width: 300, height: 200));
    });

    test('reads a lossless frame header the decoder rejects (SOF3)', () {
      final f = write(
        'lossless.jpg',
        jpegBytes(width: 16, height: 9, sofMarker: 0xc3),
      );

      expect(readImageDimensions(f, 'image/jpeg'), (width: 16, height: 9));
    });

    test('does not mistake a Huffman table (DHT) for a frame header', () {
      // DHT is 0xC4, inside the SOFn marker range. Reading its payload as a
      // frame would report garbage dimensions rather than none.
      final f = write('dht.jpg', [
        0xff,
        0xd8,
        0xff,
        0xc4,
        ...u16(10),
        ...List.filled(8, 0x11),
      ]);

      expect(readImageDimensions(f, 'image/jpeg'), isNull);
    });

    test('returns null when the file ends before any frame header', () {
      final f = write('nosof.jpg', [0xff, 0xd8, ...appSegment(0xe0, 14)]);

      expect(readImageDimensions(f, 'image/jpeg'), isNull);
    });

    test('returns null on a segment length that runs past the end', () {
      final f = write('bad.jpg', [
        0xff,
        0xd8,
        0xff,
        0xe1,
        ...u16(40000),
        0x00,
        0x00,
      ]);

      expect(readImageDimensions(f, 'image/jpeg'), isNull);
    });

    test('returns null on a zero-sized frame', () {
      final f = write('zero.jpg', jpegBytes(width: 0, height: 0));

      expect(readImageDimensions(f, 'image/jpeg'), isNull);
    });
  });

  group('HEIC', () {
    test('reads the primary item stored size from ispe', () {
      final f = write(
        'a.heic',
        heicWithProperties(
          properties: ispe(4032, 3024),
          associations: [
            ipmaEntry(1, [1]),
          ],
          primaryItem: 1,
        ),
      );

      // Today this returns null: the file is read in full and package:image
      // has no HEIC decoder at all.
      expect(readImageDimensions(f, 'image/heic'), (width: 4032, height: 3024));
    });

    test('picks the primary item ispe, not the first one in ipco', () {
      // A thumbnail item's ispe commonly sits ahead of the primary in ipco.
      final f = write(
        'thumb-first.heic',
        heicWithProperties(
          properties: [...ispe(320, 240), ...ispe(4032, 3024)],
          associations: [
            ipmaEntry(1, [1]),
            ipmaEntry(2, [2]),
          ],
          primaryItem: 2,
        ),
      );

      expect(readImageDimensions(f, 'image/heic'), (width: 4032, height: 3024));
    });

    test('finds the ispe when it is not the first associated property', () {
      // Real items associate hvcC, colr, pixi and irot alongside ispe, in no
      // guaranteed order. Taking only the first association would resolve to
      // hvcC and quietly fall back to the thumbnail's ispe.
      final f = write(
        'assoc-order.heic',
        heicWithProperties(
          properties: [
            ...ispe(320, 240), // the thumbnail's, first in ipco
            ...box('hvcC', List.filled(8, 0)),
            ...ispe(4032, 3024), // the primary's
          ],
          associations: [
            ipmaEntry(1, [1]),
            ipmaEntry(2, [2, 3]),
          ],
          primaryItem: 2,
        ),
      );

      expect(readImageDimensions(f, 'image/heic'), (width: 4032, height: 3024));
    });

    test('counts an extended-size (64-bit) property when indexing ipco', () {
      // ipma indices are positional over ipco's full child list, so a child
      // using the size==1 form has to be walked correctly or every later
      // index is off by one and resolves to the wrong property.
      final f = write(
        'largesize.heic',
        heicWithProperties(
          properties: [
            ...ispe(320, 240), // the thumbnail's, first in ipco
            ...box('hvcC', List.filled(8, 0), largeSize: true),
            ...ispe(4032, 3024), // the primary's, index 3
          ],
          associations: [
            ipmaEntry(1, [1]),
            ipmaEntry(2, [3]),
          ],
          primaryItem: 2,
        ),
      );

      expect(readImageDimensions(f, 'image/heic'), (width: 4032, height: 3024));
    });

    test('counts a to-end-of-range (size 0) property when indexing ipco', () {
      // The size==0 form means "runs to the end of the enclosing box"; it can
      // only be the last child, and it must still occupy one index.
      final f = write(
        'sizezero.heic',
        heicWithProperties(
          properties: [
            ...ispe(320, 240),
            // ispe with a size field of 0 rather than its real length.
            ...u32(0), ...'ispe'.codeUnits,
            0, 0, 0, 0, // version + flags
            ...u32(4032), ...u32(3024),
          ],
          associations: [
            ipmaEntry(1, [1]),
            ipmaEntry(2, [2]),
          ],
          primaryItem: 2,
        ),
      );

      expect(readImageDimensions(f, 'image/heic'), (width: 4032, height: 3024));
    });

    test('falls back to the first ispe when pitm is absent', () {
      final f = write(
        'nopitm.heic',
        heicWithProperties(
          properties: ispe(1600, 1200),
          associations: [
            ipmaEntry(1, [1]),
          ],
          primaryItem: 1,
          includePitm: false,
        ),
      );

      expect(readImageDimensions(f, 'image/heic'), (width: 1600, height: 1200));
    });

    test('returns null when the file carries no ispe', () {
      final f = write('noispe.heic', [
        ...box('ftyp', 'heic'.codeUnits),
        ...box('meta', [0, 0, 0, 0]),
      ]);

      expect(readImageDimensions(f, 'image/heic'), isNull);
    });

    test('reads a HEIF the same way', () {
      final f = write(
        'a.heif',
        heicWithProperties(
          properties: ispe(800, 600),
          associations: [
            ipmaEntry(1, [1]),
          ],
          primaryItem: 1,
        ),
      );

      expect(readImageDimensions(f, 'image/heif'), (width: 800, height: 600));
    });
  });

  group('other containers', () {
    test('reads PNG through the decoder', () {
      final f = write('a.png', img.encodePng(img.Image(width: 12, height: 5)));

      expect(readImageDimensions(f, 'image/png'), (width: 12, height: 5));
    });

    test('reads GIF through the decoder', () {
      final f = write('a.gif', img.encodeGif(img.Image(width: 9, height: 6)));

      expect(readImageDimensions(f, 'image/gif'), (width: 9, height: 6));
    });

    test('sniffs content, so a JPEG named .png still answers', () {
      // The "file whose name lies" case the old findDecoderForData fallback
      // covered. Dispatch is on magic bytes, never on the declared mime.
      final f = write('liar.png', jpegBytes(width: 64, height: 48));

      expect(readImageDimensions(f, 'image/png'), (width: 64, height: 48));
    });
  });

  group('non-images', () {
    test('returns null for a video mime without opening the file', () {
      final f = write('clip.mp4', List.filled(64, 0));

      expect(readImageDimensions(f, 'video/mp4'), isNull);
    });

    test('returns null for a container nothing recognises', () {
      final f = write('junk.png', List.filled(4096, 0x42));

      expect(readImageDimensions(f, 'image/png'), isNull);
    });

    test('returns null for an empty file', () {
      final f = write('empty.jpg', const []);

      expect(readImageDimensions(f, 'image/jpeg'), isNull);
    });

    test('returns null for a file that does not exist', () {
      expect(
        readImageDimensions(File('${tempDir.path}/gone.jpg'), 'image/jpeg'),
        isNull,
      );
    });
  });
}
