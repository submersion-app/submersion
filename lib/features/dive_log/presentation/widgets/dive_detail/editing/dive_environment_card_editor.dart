import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/suggested_text_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/enum_picker_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';

const _log = LoggerService('DiveEnvironmentCardEditor');

/// The Environment card's editor: the weather the diver logged, with the
/// fetch that fills it in, then the dive conditions. Rows keep the order the
/// read card shows them in.
class DiveEnvironmentCardEditor extends ConsumerStatefulWidget {
  const DiveEnvironmentCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveEnvironmentCardEditor> createState() =>
      _DiveEnvironmentCardEditorState();
}

class _DiveEnvironmentCardEditorState
    extends ConsumerState<DiveEnvironmentCardEditor> {
  late FieldTextBinding<Dive, String?> _description = _describe();
  late FieldTextBinding<Dive, String?> _surfaceConditions = _words(
    diveSurfaceConditionsField,
  );
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    // Whether the exit mirrors the entry is settled the first time the
    // sitting is asked (see [exitFollows]), as the card opens at the latest:
    // asked first at the change of entry method, it would be worked out
    // from a dive that may have changed underneath meanwhile.
    exitFollows(widget.session);
  }

  /// A free-text row: blank is no value.
  FieldTextBinding<Dive, String?> _words(
    EditField<Dive, String?> field, {
    VoidCallback? onEdited,
  }) {
    return FieldTextBinding<Dive, String?>(
      session: widget.session,
      field: field,
      format: (value) => value ?? '',
      parse: (text) => FieldValue(trimmedOrNull(text)),
      onEdited: onEdited,
    );
  }

  /// The weather description, which the diver's own edit takes over from a
  /// forecast ([weatherDescriptionEdited]).
  FieldTextBinding<Dive, String?> _describe() {
    final session = widget.session;
    return _words(
      diveWeatherDescriptionField,
      onEdited: () => weatherDescriptionEdited(session),
    );
  }

  @override
  void didUpdateWidget(DiveEnvironmentCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _description.dispose();
    _surfaceConditions.dispose();
    _description = _describe();
    _surfaceConditions = _words(diveSurfaceConditionsField);
    exitFollows(widget.session);
  }

  @override
  void dispose() {
    _description.dispose();
    _surfaceConditions.dispose();
    super.dispose();
  }

  /// Whether the fetch would replace weather the dive already has. Air
  /// temperature does not count: the fetch never replaces it.
  bool _hasWeather(EditSession<Dive> session) =>
      session.valueOf(diveWindSpeedField) != null ||
      session.valueOf(diveHumidityField) != null ||
      session.valueOf(diveWeatherDescriptionField) != null ||
      session.valueOf(diveWindDirectionField) != null ||
      session.valueOf(diveCloudCoverField) != null ||
      session.valueOf(divePrecipitationField) != null;

  Future<bool> _confirmReplace() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      // The question is the whole of it: the dive form repeats it as the
      // body under the title.
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveLog_edit_fetchWeatherConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_ok),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _fetchWeather() async {
    final session = widget.session;
    final location = session.working.site?.location;
    if (location == null || _fetching) return;
    if (_hasWeather(session) && !await _confirmReplace()) return;
    if (!mounted) return;

    // Read now: none of this may be read once the card has closed.
    final weather = ref.read(weatherServiceProvider);
    final resolver = AltitudeResolver(
      elevationService: ref.read(elevationServiceProvider),
    );
    final sites = ref.read(siteRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    final dive = session.working;

    setState(() => _fetching = true);
    try {
      final data = await weather.fetchWeather(
        latitude: location.latitude,
        longitude: location.longitude,
        date: dive.dateTime,
        entryTime: dive.effectiveEntryTime,
      );
      // The card closed, or the sitting ended or is being saved, while
      // the fetch ran: the forecast has nowhere to go.
      if (!mounted || session.isDisposed || session.isFrozen) return;
      // The dive changed underneath while it ran, its site or its time: the
      // forecast is for another place or hour.
      final now = session.working;
      if (now.site?.location != location ||
          now.dateTime != dive.dateTime ||
          now.effectiveEntryTime != dive.effectiveEntryTime) {
        return;
      }
      if (data == null) {
        _sayUnavailable(messenger, l10n, errorColor);
        return;
      }
      applyFetchedWeather(session, data, now: DateTime.now());
      // The diver has just asked for a network fill, so try the altitude
      // as well: a lookup made when the Altitude card opened may have
      // failed for want of a connection.
      unawaited(
        fillAltitudeIfEmpty(
          session,
          resolver: resolver,
          writeSiteAltitude: sites.fillSiteAltitudeIfEmpty,
          stillWanted: () => mounted,
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveLog_edit_weatherFetched)),
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Weather fetch failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _sayUnavailable(messenger, l10n, errorColor);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _sayUnavailable(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    Color color,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_edit_fetchWeatherUnavailable),
        backgroundColor: color,
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
        final site = session.working.site;
        final canFetch = site != null && site.hasCoordinates;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FormOverline(
              label: l10n.diveLog_detail_subsection_weather,
              actions: [
                FormOverlineAction(
                  label: l10n.diveLog_edit_button_fetchWeather,
                  icon: Icons.cloud_download,
                  busy: _fetching,
                  onPressed: canFetch ? _fetchWeather : null,
                ),
              ],
            ),
            ..._weatherRows(l10n, units),
            FormOverline(label: l10n.diveLog_detail_subsection_diveConditions),
            ..._conditionRows(l10n, units),
          ],
        );
      },
    );
  }

  List<Widget> _weatherRows(AppLocalizations l10n, UnitFormatter units) {
    final session = widget.session;
    final pressure = session.valueOf(diveSurfacePressureField);
    return [
      RecordNumberRow<Dive>(
        session: session,
        field: diveAirTempField,
        label: l10n.diveLog_edit_label_airTemp,
        suffixText: units.temperatureSymbol,
        toDisplay: units.convertTemperature,
        fromDisplay: units.temperatureToCelsius,
        // As the read card shows a temperature: one decimal when it has one.
        fractionDigits: 1,
        trimZeros: true,
      ),
      // Shown here as on the read card, and edited on the Altitude card, so
      // a tap leads there: the card opens, brought in from the Add strip if
      // the page was leaving it out, and scrolls into view (issue #4527).
      if (pressure != null)
        FormRow.picker(
          label: l10n.diveLog_edit_label_surfacePressure,
          value: units.formatSurfacePressure(pressure),
          // The editor is only ever open in a sitting, under its scope.
          onTap: () => RecordEditScope.maybeOf<Dive>(
            context,
          )?.addCard(diveSurfacePressureField.cardId),
        ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveWindSpeedField,
        label: l10n.diveLog_edit_label_windSpeed,
        suffixText: units.windSpeedSymbol,
        toDisplay: units.convertWindSpeed,
        fromDisplay: units.windSpeedToMs,
        // As the read card shows it when whole; a decimal stays so the row
        // can still round the value.
        fractionDigits: 1,
        trimZeros: true,
        allowNegative: false,
      ),
      EnumPickerRow<CurrentDirection>(
        label: l10n.diveLog_edit_label_windDirection,
        value: session.valueOf(diveWindDirectionField),
        values: CurrentDirection.values,
        displayName: (value) => value.localizedName(l10n),
        onChanged: (value) => session.set(diveWindDirectionField, value),
      ),
      EnumPickerRow<CloudCover>(
        label: l10n.diveLog_edit_label_cloudCover,
        value: session.valueOf(diveCloudCoverField),
        values: CloudCover.values,
        displayName: (value) => value.localizedName(l10n),
        onChanged: (value) {
          session.set(diveCloudCoverField, value);
          weatherSkyEdited(session);
        },
      ),
      EnumPickerRow<Precipitation>(
        label: l10n.diveLog_edit_label_precipitation,
        value: session.valueOf(divePrecipitationField),
        values: Precipitation.values,
        displayName: (value) => value.localizedName(l10n),
        onChanged: (value) {
          session.set(divePrecipitationField, value);
          weatherSkyEdited(session);
        },
      ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveHumidityField,
        label: l10n.diveLog_edit_label_humidity,
        suffixText: '%',
        allowNegative: false,
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_weatherDescription,
        controller: _description.controller,
        maxLines: 2,
      ),
    ];
  }

  List<Widget> _conditionRows(AppLocalizations l10n, UnitFormatter units) {
    final session = widget.session;
    return [
      EnumPickerRow<CurrentDirection>(
        label: l10n.diveLog_edit_label_currentDirection,
        value: session.valueOf(diveCurrentDirectionField),
        values: CurrentDirection.values,
        displayName: (value) => value.localizedName(l10n),
        onChanged: (value) => session.set(diveCurrentDirectionField, value),
      ),
      EnumPickerRow<CurrentStrength>(
        label: l10n.diveLog_edit_label_currentStrength,
        value: session.valueOf(diveCurrentStrengthField),
        values: CurrentStrength.values,
        displayName: (value) => value.localizedName(l10n),
        onChanged: (value) => session.set(diveCurrentStrengthField, value),
      ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveSwellHeightField,
        label: l10n.diveLog_edit_label_swellHeight,
        suffixText: units.depthSymbol,
        toDisplay: units.convertDepth,
        fromDisplay: units.depthToMeters,
        fractionDigits: 1,
        allowNegative: false,
      ),
      SuggestedTextRow(
        label: l10n.diveLog_edit_label_surfaceConditions,
        controller: _surfaceConditions.controller,
        field: DiveTextSuggestionField.surfaceConditions,
        capitalization: TextCapitalization.sentences,
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_entryMethod,
        value: session.valueOf(diveEntryMethodField),
        values: EntryMethod.values,
        displayName: (value) => value.localizedName(l10n),
        // A dive with no entry method of its own shows its site's.
        hint: session.working.site?.soleEntryMethod?.localizedName(l10n),
        onChanged: (value) =>
            setEntryMethod(session, value, exitFollows: exitFollows(session)),
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_exitMethod,
        value: session.valueOf(diveExitMethodField),
        values: EntryMethod.values,
        displayName: (value) => value.localizedName(l10n),
        onChanged: (value) {
          // Edited directly: for the rest of the sitting it no longer
          // mirrors the entry, however often the card is opened.
          exitEditedDirectly(session);
          session.set(diveExitMethodField, value);
        },
      ),
    ];
  }
}
