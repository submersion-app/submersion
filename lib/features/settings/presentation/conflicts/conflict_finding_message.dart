import 'dart:convert';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_unit_formatters.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _log = LoggerService('ConflictFindingMessage');

/// Rebuilds a finding from its synced row so the data-quality renderer can
/// turn its numeric params into a localized sentence.
///
/// Returns null when the row cannot be read as a finding (a category from a
/// newer schema, malformed params, a missing column); the comparison then
/// falls back to showing the raw columns.
QualityFindingMessage? conflictFindingMessage(
  AppLocalizations l10n,
  UnitFormatter units,
  Map<String, dynamic> data,
) {
  final detectorId = data['detectorId'];
  if (detectorId is! String || detectorId.isEmpty) return null;
  try {
    final finding = QualityFinding(
      id: data['id'] as String? ?? '',
      diveId: data['diveId'] as String? ?? '',
      detectorId: detectorId,
      detectorVersion: (data['detectorVersion'] as num?)?.toInt() ?? 0,
      category: QualityCategory.values.byName(data['category'] as String),
      severity: QualitySeverity.values.byName(data['severity'] as String),
      status: QualityStatus.values.byName(data['status'] as String),
      params:
          jsonDecode(data['params'] as String? ?? '{}') as Map<String, Object?>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
    return buildFindingMessage(l10n, finding, qualityUnitFormattersFor(units));
  } on ArgumentError catch (e) {
    _log.warning('Conflict comparison could not read a finding row', error: e);
    return null;
  } on FormatException catch (e) {
    _log.warning('Conflict comparison could not read a finding row', error: e);
    return null;
  } on TypeError catch (e) {
    _log.warning('Conflict comparison could not read a finding row', error: e);
    return null;
  }
}
