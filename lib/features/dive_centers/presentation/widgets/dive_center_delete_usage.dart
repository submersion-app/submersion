import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _log = LoggerService.forClass(DiveCenterRepository);

/// How many dives a delete of [centerIds] would leave without a center, for
/// its confirmation: a center delete keeps the dives that used it, with the
/// center cleared (issue #1952).
///
/// The count only informs the confirmation, so a failed read opens it
/// without one rather than blocking the delete.
Future<int> readDiveCenterDeleteUsage(
  WidgetRef ref,
  List<String> centerIds,
) async {
  try {
    return await ref
        .read(diveCenterRepositoryProvider)
        .getLinkedDiveCount(centerIds);
  } catch (e, stackTrace) {
    _log.warning(
      'Could not count the dives a dive center delete unlinks',
      error: e,
      stackTrace: stackTrace,
    );
    return 0;
  }
}

/// [body], then a paragraph saying how many dives keep going without their
/// center when [diveCount] is not zero.
String withDiveCenterDeleteUsage(
  AppLocalizations l10n,
  String body,
  int diveCount,
) => [
  body,
  if (diveCount > 0) l10n.diveCenters_dialog_deleteDivesKept(diveCount),
].join('\n\n');
