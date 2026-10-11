import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

void main() {
  test('a camera image is re-encoded to JPEG, keeping the side', () async {
    final capture = DocumentPageCapture(
      pickImage: (_) async => (bytes: Uint8List(50), name: 'IMG_1.HEIC'),
      encode: (picked) async => (
        outcome: ImageEncodeOutcome.encoded,
        bytes: Uint8List.fromList([7, 7]),
      ),
    );
    final r = await capture.fromImage(
      ImageSource.camera,
      side: DocumentPageSide.front,
    );
    r as PageCaptured;
    expect(r.page.mimeType, 'image/jpeg');
    expect(r.page.bytes, [7, 7]);
    expect(r.page.sizeBytes, 2);
    expect(r.page.side, DocumentPageSide.front);
    expect(r.page.fileName, 'IMG_1.jpg');
    expect(r.page.id, isEmpty);
  });

  test('a cancelled pick reports cancelled', () async {
    final capture = DocumentPageCapture(
      pickImage: (_) async => null,
      pickFile: (_) async => null,
    );
    expect(
      await capture.fromImage(ImageSource.gallery),
      isA<PageCaptureCancelled>(),
    );
    expect(await capture.fromFile(), isA<PageCaptureCancelled>());
  });

  test('an undecodable image is refused', () async {
    final capture = DocumentPageCapture(
      pickImage: (_) async => (bytes: Uint8List(5), name: 'a.jpg'),
      encode: (picked) async =>
          (outcome: ImageEncodeOutcome.undecodable, bytes: null),
    );
    expect(
      await capture.fromImage(ImageSource.gallery),
      isA<PageCaptureUndecodable>(),
    );
  });

  test('an image beyond the pixel limit is refused', () async {
    final capture = DocumentPageCapture(
      pickImage: (_) async => (bytes: Uint8List(5), name: 'a.jpg'),
      encode: (picked) async =>
          (outcome: ImageEncodeOutcome.tooLarge, bytes: null),
    );
    expect(
      await capture.fromImage(ImageSource.gallery),
      isA<PageCaptureImageTooLarge>(),
    );
  });

  test('a PDF over 10 MB is refused, at 10 MB accepted as-is', () async {
    final over = DocumentPageCapture(
      pickFile: (_) async =>
          (bytes: Uint8List(kMaxDocumentPageBytes + 1), name: 'a.pdf'),
    );
    final refused = await over.fromFile();
    expect(refused, isA<PageCaptureTooLarge>());
    expect(
      (refused as PageCaptureTooLarge).sizeBytes,
      kMaxDocumentPageBytes + 1,
    );
    final at = DocumentPageCapture(
      pickFile: (_) async =>
          (bytes: Uint8List(kMaxDocumentPageBytes), name: 'policy.pdf'),
    );
    final r = await at.fromFile() as PageCaptured;
    expect(r.page.mimeType, 'application/pdf');
    expect(r.page.fileName, 'policy.pdf');
  });

  test('the file picker is offered the gate extensions', () async {
    List<String>? offered;
    final capture = DocumentPageCapture(
      pickFile: (extensions) async {
        offered = extensions;
        return null;
      },
    );
    await capture.fromFile();
    expect(offered, kDocumentPickerExtensions);
  });

  test('a picked PNG goes through the image encoder', () async {
    var encoded = false;
    final capture = DocumentPageCapture(
      pickFile: (_) async => (bytes: Uint8List(5), name: 'scan.png'),
      encode: (picked) async {
        encoded = true;
        return (
          outcome: ImageEncodeOutcome.encoded,
          bytes: Uint8List.fromList([1]),
        );
      },
    );
    final r = await capture.fromFile();
    expect(encoded, isTrue);
    expect((r as PageCaptured).page.fileName, 'scan.jpg');
  });

  test('an unsupported extension is refused', () async {
    final capture = DocumentPageCapture(
      pickFile: (_) async => (bytes: Uint8List(5), name: 'track.gpx'),
    );
    final r = await capture.fromFile();
    expect((r as PageCaptureUnsupported).extension, 'gpx');
  });
}
