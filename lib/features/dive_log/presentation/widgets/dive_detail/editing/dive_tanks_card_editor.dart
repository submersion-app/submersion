import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/services/dive_tank_config_adapter.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_confirm_dialog.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_menu.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_gas_switches.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/scr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_caption.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_form.dart';
import 'package:submersion/shared/widgets/record_editing/stored_follow.dart';

const _log = LoggerService('DiveTanksCardEditor');

/// The Tanks card's editor, titled "Cylinders" as its read card is: the
/// dive mode and its rebreather settings, the cylinders, a saved
/// configuration, the gas switches and the pressure series reassign
/// (issue #4527).
///
/// A gauge dive logs no gas, so its editor shows the mode alone; its
/// cylinders are kept, hidden, as the dive form keeps them.
class DiveTanksCardEditor extends ConsumerStatefulWidget {
  const DiveTanksCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveTanksCardEditor> createState() =>
      _DiveTanksCardEditorState();
}

class _DiveTanksCardEditorState extends ConsumerState<DiveTanksCardEditor> {
  TankPresetEntity? _defaultPreset;

  /// Moves when the stored cylinders change underneath (a sync), so the
  /// rows show the new values instead of writing their old text back.
  final _followed = StoredFollow<Dive, List<DiveTank>>(diveTanksField);

  @override
  void initState() {
    super.initState();
    _loadGasSwitches();
    _loadDefaultPreset();
  }

  /// Read when the sitting started (`startDiveSitting`); asked again here
  /// for a sitting started without it, and a no-op otherwise.
  void _loadGasSwitches() => loadDiveGasSwitches(widget.session, ref.read);

  /// The diver's default cylinder, for Add cylinder: a built-in preset at
  /// once, one of their own once it has been read (`_loadDefaultPreset`).
  Future<void> _loadDefaultPreset() async {
    final name = ref.read(settingsProvider.select((s) => s.defaultTankPreset));
    if (name == null) return;
    final builtIn = TankPresets.byName(name);
    if (builtIn != null) _defaultPreset = TankPresetEntity.fromBuiltIn(builtIn);
    try {
      final resolver = DefaultTankPresetResolver(
        repository: ref.read(tankPresetRepositoryProvider),
      );
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final preset = await resolver.resolve(name, diverId: diverId);
      if (mounted && preset != null) _defaultPreset = preset;
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the default cylinder failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  EditSession<Dive> get _session => widget.session;

  TripSlotReader _slotReader() => tripSlotReader(
    ProviderScope.containerOf(context, listen: false),
    _session.stored.id,
  );

  void _addTank() {
    final settings = ref.read(settingsProvider);
    setTanks(_session, [
      ..._session.valueOf(diveTanksField),
      newSittingTank(
        tanks: _session.valueOf(diveTanksField),
        preset: _defaultPreset,
        defaultVolume: settings.defaultTankVolume,
        defaultStartPressure: settings.defaultStartPressure,
      ),
    ]);
    suggestTankSlots(_session, readSlots: _slotReader());
  }

  void _changeTank(DiveTank updated) {
    final tanks = _session.valueOf(diveTanksField);
    final before = tanks.where((t) => t.id == updated.id).firstOrNull;
    if (before == null) return;
    if (updated.tripCylinderId != before.tripCylinderId) {
      tankSlotChosen(
        _session,
        updated.id,
        none: updated.tripCylinderId == null,
      );
    }
    setTanks(_session, [
      for (final t in tanks) t.id == updated.id ? updated : t,
    ]);
  }

  /// A saved configuration merged into the cylinders, as the form does
  /// (`_applyCylinderConfig`): what it would overwrite is asked first.
  Future<void> _applyConfig(CylinderConfig config) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final units = ref.read(unitFormatterProvider);
    const adapter = DiveTankConfigAdapter();
    final tanks = _session.valueOf(diveTanksField);
    var result = adapter.apply(
      tanks: tanks,
      items: config.items,
      newId: (_) => newSittingTankId(),
    );
    if (result.overwrites.isNotEmpty) {
      final confirmed = await confirmCylinderOverwrites(
        context,
        configName: config.name,
        overwrites: result.overwrites,
        tanks: tanks,
        units: units,
      );
      if (!confirmed || !mounted) return;
      if (_session.isDisposed || _session.isFrozen) return;
      // Over the cylinders as they are now: one that came while the
      // question was open is kept.
      result = adapter.apply(
        tanks: _session.valueOf(diveTanksField),
        items: config.items,
        newId: (_) => newSittingTankId(),
        overwrite: true,
      );
    }
    if (_session.isDisposed || _session.isFrozen) return;
    if (!result.changed) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.cylinderConfigs_applyNothingToDo)),
      );
      return;
    }
    setTanks(_session, result.tanks, replaced: true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l10n.cylinderConfigs_applyAdded(result.added),
            l10n.cylinderConfigs_applyKept(result.kept),
            if (result.updated > 0)
              l10n.cylinderConfigs_applyUpdated(result.updated),
          ].join(', '),
        ),
      ),
    );
  }

  /// [pressures] are the readings as the sitting holds them
  /// ([tankReadingsInSitting]). A cylinder added in the sitting has none
  /// and no row yet to move them onto, so it is left out.
  Future<void> _reassign(Map<String, List<TankPressurePoint>> pressures) {
    final repository = ref.read(tankPressureRepositoryProvider);
    final diveId = _session.stored.id;
    final storedIds = {for (final t in _session.stored.tanks) t.id};
    final working = _session.working;
    return showTankSeriesReassignSheet(
      context,
      ref,
      dive: working.copyWith(
        tanks: [
          for (final t in working.tanks)
            if (storedIds.contains(t.id)) t,
        ],
      ),
      tankPressures: pressures,
      onExchange: (a, b) async {
        if (!mounted) return;
        exchangeTankSeries(
          _session,
          a,
          b,
          exchange: (x, y) => repository.exchangeTankSources(
            diveId: diveId,
            tankIdA: x,
            tankIdB: y,
            includePressures: false,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final mode = _session.valueOf(diveModeField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._modeRows(context, mode),
            if (mode != DiveMode.gauge)
              RecordCardForm<Dive>(
                cardId: diveTanksCardId,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?_rebreatherPanel(mode),
                    ..._cylinderRows(context, units, mode),
                    DiveTankGasSwitches(session: _session, units: units),
                    ..._reassignRows(context),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _modeRows(BuildContext context, DiveMode mode) {
    final theme = Theme.of(context);
    return [
      FormRow.custom(
        label: context.l10n.diveLog_diveMode_title,
        child: DiveModeSelector(
          selectedMode: mode,
          dense: true,
          onChanged: (next) => setDiveMode(
            _session,
            next,
            seedLow: ref.read(ccrSetpointLowProvider),
            seedHigh: ref.read(ccrSetpointHighProvider),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Text(
          DiveModeSelector.descriptionFor(context, mode),
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }

  Widget? _rebreatherPanel(DiveMode mode) {
    final s = _session;
    final scrubber = s.valueOf(diveScrubberField);
    ScrubberInfo? scrubberOf(String? type, int? rated, int? remaining) =>
        type == null
        ? null
        : ScrubberInfo(
            type: type,
            ratedMinutes: rated,
            remainingMinutes: remaining,
          );
    if (mode == DiveMode.ccr) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: CcrSettingsPanel(
          setpointLow: s.valueOf(diveSetpointLowField),
          setpointHigh: s.valueOf(diveSetpointHighField),
          setpointLowHint: ref.watch(ccrSetpointLowProvider),
          setpointHighHint: ref.watch(ccrSetpointHighProvider),
          setpointDeco: s.valueOf(diveSetpointDecoField),
          diluentGas: s.valueOf(diveDiluentGasField),
          scrubberType: scrubber?.type,
          scrubberDurationMinutes: scrubber?.ratedMinutes,
          scrubberRemainingMinutes: scrubber?.remainingMinutes,
          loopVolume: s.valueOf(diveLoopVolumeField),
          onChanged:
              ({
                setpointLow,
                setpointHigh,
                setpointDeco,
                diluentGas,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
                loopVolume,
              }) {
                s
                  ..set(diveSetpointLowField, setpointLow)
                  ..set(diveSetpointHighField, setpointHigh)
                  ..set(diveSetpointDecoField, setpointDeco)
                  ..set(diveDiluentGasField, diluentGas)
                  ..set(
                    diveScrubberField,
                    scrubberOf(
                      scrubberType,
                      scrubberDurationMinutes,
                      scrubberRemainingMinutes,
                    ),
                  )
                  ..set(diveLoopVolumeField, loopVolume);
              },
        ),
      );
    }
    if (mode == DiveMode.scr) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: ScrSettingsPanel(
          scrType: s.valueOf(diveScrTypeField),
          injectionRate: s.valueOf(diveScrInjectionRateField),
          additionRatio: s.valueOf(diveScrAdditionRatioField),
          orificeSize: s.valueOf(diveScrOrificeSizeField),
          supplyGas: s.valueOf(diveDiluentGasField),
          assumedVo2: s.valueOf(diveAssumedVo2Field),
          loopO2Min: s.valueOf(diveLoopO2MinField),
          loopO2Max: s.valueOf(diveLoopO2MaxField),
          loopO2Avg: s.valueOf(diveLoopO2AvgField),
          scrubberType: scrubber?.type,
          scrubberDurationMinutes: scrubber?.ratedMinutes,
          scrubberRemainingMinutes: scrubber?.remainingMinutes,
          onChanged:
              ({
                scrType,
                injectionRate,
                additionRatio,
                orificeSize,
                supplyGas,
                assumedVo2,
                loopO2Min,
                loopO2Max,
                loopO2Avg,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
              }) {
                s
                  ..set(diveScrTypeField, scrType)
                  ..set(diveScrInjectionRateField, injectionRate)
                  ..set(diveScrAdditionRatioField, additionRatio)
                  ..set(diveScrOrificeSizeField, orificeSize)
                  ..set(diveDiluentGasField, supplyGas)
                  ..set(diveAssumedVo2Field, assumedVo2)
                  ..set(diveLoopO2MinField, loopO2Min)
                  ..set(diveLoopO2MaxField, loopO2Max)
                  ..set(diveLoopO2AvgField, loopO2Avg)
                  ..set(
                    diveScrubberField,
                    scrubberOf(
                      scrubberType,
                      scrubberDurationMinutes,
                      scrubberRemainingMinutes,
                    ),
                  );
              },
        ),
      );
    }
    return null;
  }

  List<Widget> _cylinderRows(
    BuildContext context,
    UnitFormatter units,
    DiveMode mode,
  ) {
    final l10n = context.l10n;
    final dive = _session.working;
    final tanks = _session.valueOf(diveTanksField);
    final tripId = dive.tripId ?? dive.trip?.id;
    final slotStates = tripId == null
        ? null
        : ref
              .watch(
                tripCylinderStatesAtProvider((
                  tripId: tripId,
                  atMillis: dive.effectiveEntryTime.millisecondsSinceEpoch,
                  excludeDiveId: dive.id,
                )),
              )
              .value;
    final primarySourceId = ref
        .watch(diveDataSourcesProvider(dive.id))
        .value
        ?.where((s) => s.isPrimary)
        .firstOrNull
        ?.id;
    final suggested = suggestedTankIds(_session);
    final generation = (
      tankRowsGeneration(_session),
      _followed.generationOf(_session),
    );
    return [
      FormOverline(label: l10n.diveLog_edit_overline_tanks),
      FormCaption(l10n.diveLog_edit_tanksCaption),
      for (var i = 0; i < tanks.length; i++)
        TankRow(
          key: ValueKey((tanks[i].id, generation)),
          tank: tanks[i],
          tankNumber: i + 1,
          units: units,
          tripCylinderStates: slotStates,
          takenTripCylinderIds: tripCylinderIdsTakenFor(
            tanks[i],
            tanks,
            primaryComputerId: _session.stored.computerId,
            primarySourceId: primarySourceId,
          ),
          suggested: suggested.contains(tanks[i].id),
          diveId: dive.id,
          diveMode: mode,
          diveDate: dive.effectiveEntryTime,
          onChanged: _changeTank,
          onRemove: tanks.length > 1
              ? () => removeSittingTank(_session, tanks[i].id)
              : null,
          canRemove: tanks.length > 1,
          // An own cylinder, scanned (issue #2335) or picked from My
          // cylinders (issue #2599), joins the dive's gear: the Equipment
          // card gets its dot. The tank row itself never links to it.
          // It goes on if this card closes while its parts are read.
          onOwnCylinderUsed: (item) => addGearToSitting(
            ProviderScope.containerOf(context, listen: false).read,
            _session,
            [item],
          ),
          // Save waits for a scan still being read.
          onScanPending: _session.track,
        ),
      FormAppendRow(label: l10n.diveLog_edit_addTank, onTap: _addTank),
      ApplyConfigurationMenu(onSelected: _applyConfig),
    ];
  }

  List<Widget> _reassignRows(BuildContext context) {
    // Moved by the exchanges already held, so a second reassign shows what
    // each cylinder holds now.
    final pressures = tankReadingsInSitting(
      _session,
      ref.watch(tankPressuresProvider(_session.stored.id)).value,
    );
    if (!CylindersCard.canReassignTankSeries(_session.working, pressures)) {
      return const [];
    }
    final l10n = context.l10n;
    return [
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          icon: const Icon(Icons.swap_vert),
          label: Text(l10n.diveLog_tank_reassignSeries),
          onPressed: () => _reassign(pressures ?? const {}),
        ),
      ),
      if (heldTankSeriesExchanges(_session).isNotEmpty)
        FormCaption(l10n.diveLog_tank_reassignPending),
    ];
  }
}
