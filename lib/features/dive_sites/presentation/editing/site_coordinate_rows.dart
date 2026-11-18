import 'package:flutter/material.dart';

import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/coordinate_field_group.dart';
import 'package:submersion/shared/widgets/forms/coordinate_validation_messages.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_form.dart';

/// The site's position as a pair of coordinate rows, bound to
/// [siteLocationField] (issue #4527, phase 2).
///
/// The rows keep decimal-degree text, as the form's do; [format] is only how
/// they are shown. Both blank is no position; both readable and in range is
/// one. Anything else (a half-typed position, a latitude past 90) stays in
/// the input the diver is typing in: [CoordinateFieldGroup] never hands it
/// to these rows, and the input fails its own validator, which the card's
/// form reports to the page, so the card stays open and Save is refused.
/// Nothing reaches the sitting.
class SiteCoordinateRows extends StatefulWidget {
  const SiteCoordinateRows({
    super.key,
    required this.session,
    required this.format,
    this.onMoved,
  });

  final EditSession<DiveSite> session;
  final CoordinateFormat format;

  /// Told of a position the diver typed, once it reads.
  final ValueChanged<GeoPoint>? onMoved;

  @override
  State<SiteCoordinateRows> createState() => _SiteCoordinateRowsState();
}

class _SiteCoordinateRowsState extends State<SiteCoordinateRows> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  /// Set while the rows show the sitting's value, so that is not an edit.
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _show(widget.session.valueOf(siteLocationField));
    _latitude.addListener(_edited);
    _longitude.addListener(_edited);
    widget.session.addListener(_follow);
  }

  /// Handed another sitting (a retake after a whole-record operation), the
  /// rows follow it and show its position.
  @override
  void didUpdateWidget(SiteCoordinateRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    oldWidget.session.removeListener(_follow);
    widget.session.addListener(_follow);
    _show(widget.session.valueOf(siteLocationField));
  }

  void _show(GeoPoint? point) {
    _showing = true;
    _latitude.text = point?.latitude.toString() ?? '';
    _longitude.text = point?.longitude.toString() ?? '';
    _showing = false;
  }

  /// What the two rows read as: a position, none (both blank), or null
  /// when they cannot be read, which [CoordinateFieldGroup] never writes.
  ({GeoPoint? point})? _read() {
    final lat = _latitude.text.trim();
    final lon = _longitude.text.trim();
    if (lat.isEmpty && lon.isEmpty) return (point: null);
    final latitude = double.tryParse(lat);
    final longitude = double.tryParse(lon);
    if (latitude == null || latitude < -90 || latitude > 90) return null;
    if (longitude == null || longitude < -180 || longitude > 180) return null;
    return (point: GeoPoint(latitude, longitude));
  }

  void _edited() {
    if (_showing) return;
    final read = _read();
    if (read == null) return;
    final point = read.point;
    if (widget.session.valueOf(siteLocationField) == point) return;
    widget.session.set(siteLocationField, point);
    if (point != null) widget.onMoved?.call(point);
  }

  /// Shows a position set elsewhere (a pick from the map, a stored change),
  /// unless the rows already read as it. Text the diver is part way through
  /// typing lives in the input, not here, and is replaced by the input
  /// when these rows change.
  void _follow() {
    if (widget.session.isDisposed) return;
    final point = widget.session.valueOf(siteLocationField);
    if (_read()?.point == point) return;
    _show(point);
  }

  @override
  void dispose() {
    widget.session.removeListener(_follow);
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RecordCardForm<DiveSite>(
      cardId: 'location',
      fieldId: 'coordinates',
      child: CoordinateFieldGroup(
        latitudeController: _latitude,
        longitudeController: _longitude,
        format: widget.format,
        latitudeLabel: l10n.diveSites_edit_gps_latitude_label,
        longitudeLabel: l10n.diveSites_edit_gps_longitude_label,
        messages: CoordinateValidationMessages.of(context),
      ),
    );
  }
}
