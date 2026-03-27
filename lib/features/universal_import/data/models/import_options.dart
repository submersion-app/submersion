import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Configuration options for an import operation.
class ImportOptions extends Equatable {
  /// The detected/confirmed source app.
  final SourceApp sourceApp;

  /// The detected/confirmed format.
  final ImportFormat format;

  const ImportOptions({required this.sourceApp, required this.format});

  @override
  List<Object?> get props => [sourceApp, format];
}
