import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Which face of a card a page shows.
enum DocumentPageSide {
  front,
  back;

  static DocumentPageSide? fromStorage(String? value) => switch (value) {
    'front' => DocumentPageSide.front,
    'back' => DocumentPageSide.back,
    _ => null,
  };
}

/// One page of a document: an embedded file (image, PDF, Word or text).
class DocumentPage extends Equatable {
  /// Empty for a page not yet saved.
  final String id;
  final String documentId;
  final int pageIndex;
  final DocumentPageSide? side;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Null when the page was loaded without its content.
  final Uint8List? bytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentPage({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    this.side,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.bytes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  DocumentPage copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    DocumentPageSide? side,
    bool clearSide = false,
    Uint8List? bytes,
    DateTime? updatedAt,
  }) => DocumentPage(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    side: clearSide ? null : (side ?? this.side),
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    bytes: bytes ?? this.bytes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// The same page without its content, for metadata-only listings.
  DocumentPage withoutBytes() => DocumentPage(
    id: id,
    documentId: documentId,
    pageIndex: pageIndex,
    side: side,
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  // bytes are left out: hashing megabytes for equality is never wanted.
  @override
  List<Object?> get props => [
    id,
    documentId,
    pageIndex,
    side,
    fileName,
    mimeType,
    sizeBytes,
    createdAt,
    updatedAt,
  ];
}
