import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// Output of the Transform stage. Typed field maps with standardized names.
class TransformedRows extends Equatable {
  /// Each map uses standardized field names (e.g., 'maxDepth', 'waterTemp').
  /// Values are typed: double, int, DateTime, Duration, String.
  final List<Map<String, dynamic>> rows;

  /// Warnings accumulated during transformation.
  final List<ImportWarning> warnings;

  /// The file role these rows came from (e.g., 'primary', 'dive_profile').
  final String fileRole;

  const TransformedRows({
    required this.rows,
    this.warnings = const [],
    this.fileRole = 'primary',
  });

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
  int get rowCount => rows.length;

  @override
  List<Object?> get props => [rows, warnings, fileRole];
}
