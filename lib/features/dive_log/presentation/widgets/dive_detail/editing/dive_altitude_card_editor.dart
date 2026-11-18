import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';

/// The Altitude card's editor: the dive's altitude and surface pressure, in
/// the diver's units, with the altitude group the read card shows.
///
/// The first time it is opened in a sitting, on a dive with no altitude, it
/// looks one up ([fillAltitudeIfEmpty]). What it finds is a change like any
/// other: the card is marked, and Cancel undoes it.
class DiveAltitudeCardEditor extends ConsumerStatefulWidget {
  const DiveAltitudeCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveAltitudeCardEditor> createState() =>
      _DiveAltitudeCardEditorState();
}

class _DiveAltitudeCardEditorState
    extends ConsumerState<DiveAltitudeCardEditor> {
  static const _lookupKey = 'altitudeLookup';

  /// Whether the altitude row holds text that is not a number. The sitting
  /// keeps the last altitude that could be read, and the group banner must
  /// not name that one's group beside text that has none (issue #4527).
  bool _altitudeUnreadable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillAltitude());
  }

  void _fillAltitude() {
    if (!mounted) return;
    final session = widget.session;
    if (session.isDisposed) return;
    // Once in a sitting, whether or not there was anything to look up: the
    // card can be opened many times, and an altitude the diver has taken
    // out since must stay out. Fetching the weather asks again.
    final first = session.firstTime(_lookupKey);
    if (!first || session.valueOf(diveAltitudeField) != null) return;
    // Read now: the write is made when the sitting is saved, which may be
    // after this card has closed.
    final sites = ref.read(siteRepositoryProvider);
    unawaited(
      fillAltitudeIfEmpty(
        session,
        resolver: AltitudeResolver(
          elevationService: ref.read(elevationServiceProvider),
        ),
        writeSiteAltitude: sites.fillSiteAltitudeIfEmpty,
        stillWanted: () => mounted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final altitude = session.valueOf(diveAltitudeField);
        final group = AltitudeGroup.fromAltitude(
          _altitudeUnreadable ? null : altitude,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RecordNumberRow<Dive>(
              session: session,
              field: diveAltitudeField,
              label: l10n.diveLog_edit_label_altitude,
              suffixText: units.altitudeSymbol,
              toDisplay: units.convertAltitude,
              fromDisplay: units.altitudeToMeters,
              onUnreadableChanged: (unreadable) {
                if (mounted) setState(() => _altitudeUnreadable = unreadable);
              },
            ),
            // Always here, so the rows around it keep their place as the
            // altitude crosses into and out of a group.
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: group == AltitudeGroup.seaLevel ? 0 : 8,
              ),
              child: AltitudeGroupBanner(group: group),
            ),
            RecordNumberRow<Dive>(
              session: session,
              field: diveSurfacePressureField,
              label: l10n.diveLog_edit_label_surfacePressure,
              suffixText: units.surfacePressureSymbol,
              toDisplay: units.convertSurfacePressure,
              fromDisplay: units.surfacePressureToBar,
              fractionDigits: units.surfacePressureDecimals,
              allowNegative: false,
              placeholder: _pressureHint(units, altitude),
            ),
          ],
        );
      },
    );
  }

  /// The pressure the read card shows when none is stored: the one worked
  /// out from the altitude, or standard pressure at sea level.
  String _pressureHint(UnitFormatter units, double? altitudeMeters) {
    final bar = AltitudeCalculator.calculateBarometricPressure(
      altitudeMeters ?? 0,
    );
    return formatFixedForInput(
      units.convertSurfacePressure(bar),
      units.surfacePressureDecimals,
    );
  }
}
