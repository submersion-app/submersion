import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/files/picked_file_materializer.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

typedef PickedBytes = ({Uint8List bytes, String name});
typedef ImagePickFn = Future<PickedBytes?> Function(ImageSource source);
typedef FilePickFn = Future<PickedBytes?> Function(List<String> extensions);
typedef EncodedImage = ({ImageEncodeOutcome outcome, Uint8List? bytes});
typedef ImageEncodeFn = Future<EncodedImage> Function(PickedBytes picked);

/// What one page capture produced.
sealed class PageCaptureResult {
  const PageCaptureResult();
}

class PageCaptured extends PageCaptureResult {
  final DocumentPage page;

  const PageCaptured(this.page);
}

class PageCaptureCancelled extends PageCaptureResult {
  const PageCaptureCancelled();
}

/// Over [kMaxDocumentPageBytes], after any re-encode.
class PageCaptureTooLarge extends PageCaptureResult {
  final int sizeBytes;

  const PageCaptureTooLarge(this.sizeBytes);
}

class PageCaptureUnsupported extends PageCaptureResult {
  final String extension;

  const PageCaptureUnsupported(this.extension);
}

class PageCaptureUndecodable extends PageCaptureResult {
  const PageCaptureUndecodable();
}

/// The source image has more pixels than the encoder will decode.
class PageCaptureImageTooLarge extends PageCaptureResult {
  const PageCaptureImageTooLarge();
}

/// Turns a camera shot, a gallery photo or a picked file into an unsaved
/// [DocumentPage]. Images are re-encoded like certification card photos
/// (2000 px, JPEG 85); other files are stored as-is under the size cap.
/// The three seams exist for tests: the platform pickers have no Dart side.
class DocumentPageCapture {
  final ImagePickFn _pickImage;
  final FilePickFn _pickFile;
  final ImageEncodeFn _encode;

  DocumentPageCapture({
    ImagePickFn? pickImage,
    FilePickFn? pickFile,
    ImageEncodeFn? encode,
  }) : _pickImage = pickImage ?? _platformPickImage,
       _pickFile = pickFile ?? _platformPickFile,
       _encode = encode ?? _platformEncode;

  Future<PageCaptureResult> fromImage(
    ImageSource source, {
    DocumentPageSide? side,
  }) async {
    final picked = await _pickImage(source);
    if (picked == null) return const PageCaptureCancelled();
    return _encodeImage(picked, side);
  }

  Future<PageCaptureResult> fromFile({DocumentPageSide? side}) async {
    final picked = await _pickFile(kDocumentPickerExtensions);
    if (picked == null) return const PageCaptureCancelled();
    final verdict = checkDocumentFile(
      fileName: picked.name,
      sizeBytes: picked.bytes.length,
    );
    return switch (verdict) {
      DocumentFileUnsupported(:final extension) => PageCaptureUnsupported(
        extension,
      ),
      DocumentFileTooLarge(:final sizeBytes) => PageCaptureTooLarge(sizeBytes),
      DocumentFileAccepted(needsImageReencode: true) => await _encodeImage(
        picked,
        side,
      ),
      DocumentFileAccepted(:final mimeType) => PageCaptured(
        _page(picked.name, mimeType, picked.bytes, side),
      ),
    };
  }

  Future<PageCaptureResult> _encodeImage(
    PickedBytes picked,
    DocumentPageSide? side,
  ) async {
    final encoded = await _encode(picked);
    switch (encoded.outcome) {
      case ImageEncodeOutcome.encoded:
        final bytes = encoded.bytes!;
        if (bytes.length > kMaxDocumentPageBytes) {
          return PageCaptureTooLarge(bytes.length);
        }
        final name = '${p.basenameWithoutExtension(picked.name)}.jpg';
        return PageCaptured(_page(name, 'image/jpeg', bytes, side));
      case ImageEncodeOutcome.tooLarge:
        return const PageCaptureImageTooLarge();
      case ImageEncodeOutcome.undecodable:
        return const PageCaptureUndecodable();
    }
  }

  DocumentPage _page(
    String name,
    String mimeType,
    Uint8List bytes,
    DocumentPageSide? side,
  ) {
    final now = DateTime.now();
    return DocumentPage(
      id: '',
      documentId: '',
      pageIndex: 0,
      side: side,
      fileName: name,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      bytes: bytes,
      createdAt: now,
      updatedAt: now,
    );
  }

  // coverage:ignore-start
  // Platform pickers and the isolate encoder: no Dart-side test double.

  /// No maxWidth / imageQuality: the desktop pickers ignore them, so the
  /// encoder does the sizing (as certification_edit_page.dart does).
  static Future<PickedBytes?> _platformPickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return null;
    return (bytes: await picked.readAsBytes(), name: picked.name);
  }

  static Future<PickedBytes?> _platformPickFile(List<String> extensions) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result.isEmpty) return null;
    // file_picker 12 returns handles; an Android SAF pick has no path until
    // it is copied out (document_open_helper.dart does the same).
    final local = await materializePickedFiles(result);
    if (local.isEmpty) return null;
    final file = local.first;
    return (bytes: await File(file.path).readAsBytes(), name: file.name);
  }

  static Future<EncodedImage> _platformEncode(PickedBytes picked) async {
    final r = await encodeStoredImage(
      ImageEncodeRequest.fromBytes(
        bytes: picked.bytes,
        spec: ImageEncodeSpec.certificationCard,
        declaredName: picked.name,
      ),
    );
    return (outcome: r.outcome, bytes: r.bytes);
  }

  // coverage:ignore-end
}
