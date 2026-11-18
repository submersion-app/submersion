import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_type_autofill.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_area_anchor_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_caption.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveSiteRow');

/// The site row of the header editor: the site's name, where it is under
/// it, and a clear button. Picking or clearing applies the site's rules to
/// the other cards ([assignDiveSite]).
class DiveSiteRow extends ConsumerWidget {
  const DiveSiteRow({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final site = session.valueOf(diveSiteField);
    final where = site?.locationString ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormRow.picker(
          label: l10n.diveLog_edit_row_site,
          value: site?.name,
          placeholder: l10n.diveLog_edit_row_addSite,
          onTap: () => pickSiteForSitting(context, ref, session),
          onClear: site == null
              ? null
              : () => readDiveSiteAssigner(context)(session, null),
          clearTooltip: l10n.common_action_remove,
        ),
        if (where.isNotEmpty) FormCaption(where),
      ],
    );
  }
}

/// Puts a site on the dive of a sitting, with its rules ([assignDiveSite]).
typedef DiveSiteAssigner =
    void Function(EditSession<Dive> session, DiveSite? site);

/// An [assignDiveSite] with everything it reads taken from [context]'s
/// providers now: the dive types read and the altitude lookup can answer
/// after the widget that asked has gone.
DiveSiteAssigner readDiveSiteAssigner(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final resolver = AltitudeResolver(
    elevationService: container.read(elevationServiceProvider),
  );
  final sites = container.read(siteRepositoryProvider);
  Future<List<String>> siteDiveTypeIds(String siteId) async =>
      diveTypeIdsForSiteTypes(
        siteTypes: await container.read(
          siteTypesForSiteProvider(siteId).future,
        ),
        diveTypes: await container.read(diveTypesProvider.future),
      );
  return (session, site) {
    final before = session.working.site?.id;
    assignDiveSite(
      session,
      site,
      siteDiveTypeIds: siteDiveTypeIds,
      resolver: resolver,
      writeSiteAltitude: sites.fillSiteAltitudeIfEmpty,
    );
    // A new site also brings, or offers, its location's equipment set: a
    // rule of the gear's, kept out of the site rules (issue #4527, plan 5).
    if (session.working.site?.id != before) {
      reevaluateGearForSite(session, read: container.read);
    }
  };
}

const _pickerOpenKey = 'sitePickerOpen';

/// Opens the site picker for the dive [session] holds, on its own GPS or,
/// lacking that, on the area of the dives logged around it, and puts the
/// site picked or created on the dive. One sheet at a time: a second tap
/// while the first is opening does nothing.
///
/// A site created from the picker exists at once and outlives a cancelled
/// sitting; only the dive's link to it is held.
Future<void> pickSiteForSitting(
  BuildContext context,
  WidgetRef ref,
  EditSession<Dive> session,
) async {
  if (session.recall<bool>(_pickerOpenKey) ?? false) return;
  session.remember(_pickerOpenKey, true);
  try {
    // Read now: the sheet can close after this widget has gone.
    final assign = readDiveSiteAssigner(context);
    final anchors = ref.read(siteAreaAnchorRepositoryProvider);
    final dive = session.working;
    final gps = dive.entryLocation ?? dive.exitLocation;
    // A dive with its own GPS needs no inference.
    final area = gps == null ? await _areaOf(ref, anchors, dive) : null;
    // A sitting saved or cancelled while the area loaded opens no picker.
    if (!context.mounted || session.isDisposed || session.isFrozen) return;
    final site = await pickOrCreateSite(
      context,
      ref,
      selectedSiteId: dive.site?.id,
      diveLocation: gps,
      areaAnchor: area,
      newSiteSeedLocation: gps,
    );
    if (site == null || session.isDisposed || session.isFrozen) return;
    assign(session, site);
  } finally {
    if (!session.isDisposed) session.remember(_pickerOpenKey, false);
  }
}

/// Where [dive] probably was, from the dives logged around it. Null when
/// nothing says; never fails the picker.
Future<SiteAreaAnchor?> _areaOf(
  WidgetRef ref,
  SiteAreaAnchorRepository anchors,
  Dive dive,
) async {
  try {
    final diverId =
        dive.diverId ?? await ref.read(validatedCurrentDiverIdProvider.future);
    return await anchors.forDive(
      at: dive.effectiveEntryTime,
      tripId: dive.tripId ?? dive.trip?.id,
      diverId: diverId,
      excludeDiveIds: [dive.id],
    );
  } catch (error, stackTrace) {
    _log.warning(
      'Could not work out the area of the dive for the site picker',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}
