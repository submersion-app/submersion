import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Configuration options for an import operation.
class ImportOptions extends Equatable {
  /// The detected/confirmed source app.
  final SourceApp sourceApp;

  /// The detected/confirmed format.
  final ImportFormat format;

  /// The source file's name, when known. Used by formats that carry no
  /// in-file dive name (e.g. Garmin FIT) to seed the dive name from the file.
  final String? fileName;

  const ImportOptions({
    required this.sourceApp,
    required this.format,
    this.fileName,
  });

  @override
  List<Object?> get props => [sourceApp, format, fileName];
}
