import 'package:path/path.dart' as p;

/// Largest page the store accepts, after any image re-encode. Every page is
/// embedded in the synced database, so this bounds what each device carries.
const int kMaxDocumentPageBytes = 10 * 1024 * 1024;

const Map<String, String> _fileMimeTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
};

/// Images the stored-image encoder decodes. HEIC is not among them, so a
/// HEIC file is refused as unsupported rather than failing to decode; the
/// camera and gallery pickers already hand back JPEG.
const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png'};

/// Extensions offered by the file picker.
const List<String> kDocumentPickerExtensions = [
  'pdf',
  'doc',
  'docx',
  'txt',
  'jpg',
  'jpeg',
  'png',
];

sealed class DocumentFileVerdict {
  const DocumentFileVerdict();
}

class DocumentFileAccepted extends DocumentFileVerdict {
  final String mimeType;

  /// Images are re-encoded like certification photos; the stored mime is
  /// then image/jpeg.
  final bool needsImageReencode;

  const DocumentFileAccepted(this.mimeType, {this.needsImageReencode = false});
}

class DocumentFileTooLarge extends DocumentFileVerdict {
  final int sizeBytes;

  const DocumentFileTooLarge(this.sizeBytes);
}

class DocumentFileUnsupported extends DocumentFileVerdict {
  final String extension;

  const DocumentFileUnsupported(this.extension);
}

/// Whether a picked file can become a page. An image passes regardless of
/// size here: the re-encode shrinks it and the caller checks again.
DocumentFileVerdict checkDocumentFile({
  required String fileName,
  required int sizeBytes,
}) {
  final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  if (_imageExtensions.contains(ext)) {
    return const DocumentFileAccepted('image/jpeg', needsImageReencode: true);
  }
  final mime = _fileMimeTypes[ext];
  if (mime == null) return DocumentFileUnsupported(ext);
  if (sizeBytes > kMaxDocumentPageBytes) return DocumentFileTooLarge(sizeBytes);
  return DocumentFileAccepted(mime);
}
