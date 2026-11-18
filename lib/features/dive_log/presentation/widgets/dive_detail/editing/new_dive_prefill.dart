import 'dart:io';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:uuid/uuid.dart';

const _log = LoggerService('NewDivePrefill');
const _uuid = Uuid();

/// The cards a new dive opens with laid out (issue #4527, plan 8): the
/// Dive card and the starter set (Tanks, Buddies, Notes), then each card
/// a prefill in [request] writes to, so what was filled in is in view.
List<String> newDiveLaidOutCards(NewDiveRequest request) {
  final p = request.prefill;
  return [
    diveHeaderCardId,
    DiveDetailSectionId.tanks.name,
    DiveDetailSectionId.buddies.name,
    DiveDetailSectionId.notes.name,
    if (p?.airTempCelsius != null) DiveDetailSectionId.environment.name,
    if (p?.weightKg != null) DiveDetailSectionId.weights.name,
    if (request.tripId != null) DiveDetailSectionId.details.name,
    if (p?.photoPath != null) DiveDetailSectionId.media.name,
  ];
}

/// Copies a logbook photo for the dive and builds its row, written at Save.
typedef LogbookPhotoPreparer =
    Future<PreparedMedia> Function(File file, DateTime? takenAt);

/// Puts what [request] brings onto a new dive's sitting (issue #4527, plan
/// 8), each value through the function a diver's own edit uses, so it is
/// a change with its card's dot and the rules across cards follow: a site
/// through [assignSite], a trip and its slot through the cylinder rules.
/// The values are mapped as the old new-dive form mapped them.
///
/// The trip and the logbook photo are read afterwards and tracked, so a
/// save waits for them; each drops its answer when the sitting has ended or
/// is being saved by then. A photo that cannot be copied is left out and
/// [onPhotoFailed] is told, so the diver hears of it, as the form says.
void applyNewDivePrefill(
  EditSession<Dive> session,
  NewDiveRequest request, {
  required DiveSiteAssigner assignSite,
  required Future<Trip?> Function(String tripId) readTrip,
  required TripSlotReader readSlots,
  required LogbookPhotoPreparer preparePhoto,
  void Function()? onPhotoFailed,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final p = request.prefill;
  if (p != null) _applyScan(session, p, assignSite);
  final tripId = request.tripId;
  if (tripId != null) {
    session.track(
      _applyTrip(session, tripId, request.tripCylinderId, readTrip, readSlots),
    );
  }
  final photoPath = p?.photoPath;
  if (photoPath != null) {
    session.track(
      _holdPhoto(session, File(photoPath), preparePhoto, onPhotoFailed),
    );
  }
}

bool _alive(EditSession<Dive> session) =>
    !session.isDisposed && !session.isFrozen;

void _applyScan(
  EditSession<Dive> session,
  DivePrefill p,
  DiveSiteAssigner assignSite,
) {
  if (p.diveNumber != null) {
    session.set(diveNumberField, p.diveNumber!.toDouble());
  }
  final date = p.dateTime;
  if (date != null) {
    final at = session.valueOf(diveEntryField);
    setEntryTime(
      session,
      DateTime.utc(
        date.year,
        date.month,
        date.day,
        p.hasTimeOfDay ? date.hour : at.hour,
        p.hasTimeOfDay ? date.minute : at.minute,
      ),
    );
  }
  if (p.durationMinutes != null) {
    session.set(diveBottomTimeField, p.durationMinutes! * 60.0);
  }
  if (p.maxDepthMeters != null) {
    session.set(diveMaxDepthField, p.maxDepthMeters);
  }
  if (p.waterTempCelsius != null) {
    session.set(diveWaterTempField, p.waterTempCelsius);
  }
  if (p.airTempCelsius != null) {
    session.set(diveAirTempField, p.airTempCelsius);
  }
  if (p.rating != null) session.set(diveRatingField, p.rating);
  if (p.notes != null) session.set(diveNotesField, p.notes!);
  if (p.site != null) assignSite(session, p.site);
  if (p.weightKg != null) {
    // Paper logs record a total; the carry type is unknown.
    session.set(diveWeightsField, [
      DiveWeight(
        id: _uuid.v4(),
        diveId: session.stored.id,
        weightType: WeightType.mixed,
        amountKg: p.weightKg!,
      ),
    ]);
  }
  final tanks = session.valueOf(diveTanksField);
  final first = _scannedTank(p, tanks.isEmpty ? null : tanks.first);
  if (first != null) {
    setTanks(session, [first, ...tanks.skip(1)], replaced: true);
  }
}

/// The first cylinder as the scan or the passport describes it over
/// [base], the starter; null when the prefill says nothing of it.
DiveTank? _scannedTank(DivePrefill p, DiveTank? base) {
  final id = base?.id ?? newSittingTankId();
  if (p.tank case final t?) {
    // A tag that gives a volume describes the cylinder itself: its spec is
    // taken whole, never mixed with the default one's. A tag with no volume
    // keeps the default cylinder, preset and all.
    final whole = t.volume != null;
    return DiveTank(
      id: id,
      name: t.name,
      volume: whole ? t.volume : base?.volume,
      workingPressure: whole
          ? t.workingPressure
          : t.workingPressure ?? base?.workingPressure,
      startPressure: t.startPressure ?? base?.startPressure,
      endPressure: t.endPressure ?? base?.endPressure,
      gasMix: t.gasMix,
      role: t.role,
      material: whole ? t.material : t.material ?? base?.material,
      order: 0,
      presetName: whole ? t.presetName : base?.presetName,
      passportId: t.passportId,
      twinPassportId: t.twinPassportId,
    );
  }
  if (p.startPressureBar == null &&
      p.endPressureBar == null &&
      p.o2Percent == null &&
      p.cylinderVolumeLiters == null) {
    return null;
  }
  return DiveTank(
    id: id,
    volume: p.cylinderVolumeLiters ?? base?.volume,
    workingPressure: base?.workingPressure,
    startPressure: p.startPressureBar ?? base?.startPressure,
    endPressure: p.endPressureBar ?? base?.endPressure,
    gasMix: p.o2Percent != null
        ? GasMix(o2: p.o2Percent!)
        : (base?.gasMix ?? const GasMix()),
    role: base?.role ?? TankRole.backGas,
    material: base?.material,
    order: 0,
    presetName: base?.presetName,
  );
}

/// The trip board's Log dive: the trip, and the first cylinder filled from
/// the slot the diver chose; every other cylinder is offered a slot as
/// usual. A trip the diver picked meanwhile stands.
Future<void> _applyTrip(
  EditSession<Dive> session,
  String tripId,
  String? cylinderId,
  Future<Trip?> Function(String tripId) readTrip,
  TripSlotReader readSlots,
) async {
  final Trip? trip;
  try {
    trip = await readTrip(tripId);
  } catch (error, stackTrace) {
    _log.warning(
      'Reading the trip failed',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }
  if (trip == null || !_alive(session)) return;
  if (session.valueOf(diveTripField) != null) return;
  session.set(diveTripField, trip);
  if (cylinderId != null) {
    try {
      final at = session.working.effectiveEntryTime;
      final slots = await readSlots(tripId, at);
      // A trip the diver changed meanwhile keeps its own slots.
      if (!_alive(session) || session.valueOf(diveTripField)?.id != tripId) {
        return;
      }
      final slot = slots.where((s) => s.cylinder.id == cylinderId).firstOrNull;
      final tanks = session.valueOf(diveTanksField);
      if (slot != null && tanks.isNotEmpty) {
        final first = tankFromTripCylinder(tanks.first, slot);
        setTanks(session, [first, ...tanks.skip(1)], replaced: true);
        tankSlotChosen(session, first.id, none: false);
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the trip slots failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  if (!_alive(session)) return;
  suggestTankSlots(session, readSlots: readSlots);
}

/// The scanned logbook page, held as a photo of the dive until Save.
Future<void> _holdPhoto(
  EditSession<Dive> session,
  File file,
  LogbookPhotoPreparer preparePhoto,
  void Function()? onFailed,
) async {
  final PreparedMedia prepared;
  try {
    prepared = await preparePhoto(file, session.working.effectiveEntryTime);
  } catch (error, stackTrace) {
    _log.warning(
      'Copying the logbook photo failed',
      error: error,
      stackTrace: stackTrace,
    );
    if (!session.isDisposed) onFailed?.call();
    return;
  }
  if (!_alive(session)) return;
  addMediaToSitting(session, [HeldMediaRow(prepared)]);
}
