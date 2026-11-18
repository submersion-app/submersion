import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';

/// What a new dive is opened with (issue #4527, plan 8): a prefill handed
/// over by the logbook scan, a cylinder passport or the Plan dive button,
/// and the trip board's Log dive shortcut as a trip and one of its
/// cylinder slots.
class NewDiveRequest {
  const NewDiveRequest({this.prefill, this.tripId, this.tripCylinderId});

  final DivePrefill? prefill;
  final String? tripId;
  final String? tripCylinderId;

  /// Opened as a planned dive: awaiting dive computer data, no number.
  bool get isPlanned => prefill?.isPlanned ?? false;
}
