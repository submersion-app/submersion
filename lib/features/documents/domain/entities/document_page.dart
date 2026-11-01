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

/// Which stored content a page holds. Every write to a page moves its hlc,
/// which also tells apart two writes in one millisecond of updatedAt, so two
/// pages with the same key hold the same bytes.
typedef DocumentPageContentKey = ({String id, DateTime updatedAt, String? hlc});

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

  /// This page's sync clock; null for a page not yet saved.
  final String? hlc;

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
    this.hlc,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  /// Whether the app draws this page, and so needs its content to show it.
  /// Any other page is a file tile, which reads it only when opened.
  bool get rendersInApp => isImage || isPdf;

  DocumentPageContentKey get contentKey =>
      (id: id, updatedAt: updatedAt, hlc: hlc);

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
    hlc: hlc,
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
    hlc: hlc,
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
    hlc,
  ];
}
