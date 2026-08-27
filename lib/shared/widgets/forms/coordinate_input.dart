import 'package:flutter/material.dart';

import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/coordinate_formatter.dart';
import 'package:submersion/core/utils/coordinates/coordinate_parser.dart';
import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// What the input currently holds, in decimal degrees.
///
/// Blank and invalid are reported separately because they mean opposite
/// things to the consumer: blank is a diver deliberately removing a
/// coordinate, invalid is a half-typed or mistaken one. Collapsing both to a
/// null pair is what let a typo erase a stored position.
class CoordinateInputValue {
  const CoordinateInputValue({
    this.latitude,
    this.longitude,
    required this.isBlank,
  });

  final double? latitude;
  final double? longitude;

  /// Every sub-field is empty.
  final bool isBlank;

  /// The sub-fields form a complete position.
  bool get isComplete => latitude != null && longitude != null;

  /// Something is entered, but it is not a position.
  bool get isInvalid => !isBlank && !isComplete;
}

/// Latitude/longitude entry that adapts its sub-fields to the diver's chosen
/// notation.
///
/// The public interface is decimal degrees in both directions, so the
/// consuming form, its validators, and the database contract never learn
/// which format is active. Only the layout changes.
///
/// UTM and MGRS are why this widget owns the whole pair rather than sitting
/// behind two independent latitude and longitude fields: a UTM zone is shared
/// between the axes and an MGRS reference encodes both in a single token, so
/// neither can be split across two fields.
class CoordinateInput extends StatefulWidget {
  const CoordinateInput({
    super.key,
    required this.format,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.latitudeLabel,
    this.longitudeLabel,
    this.errorText,
    this.invalidMessage,
  });

  final CoordinateFormat format;
  final double? latitude;
  final double? longitude;

  /// Reports what the sub-fields currently hold.
  final void Function(CoordinateInputValue value) onChanged;

  final String? latitudeLabel;
  final String? longitudeLabel;
  final String? errorText;

  /// Shown, and used to fail form validation, while the entry is invalid.
  final String? invalidMessage;

  @override
  State<CoordinateInput> createState() => _CoordinateInputState();
}

class _CoordinateInputState extends State<CoordinateInput> {
  final Map<String, TextEditingController> _controllers = {};
  String _latHemisphere = 'N';
  String _lonHemisphere = 'E';

  /// The last pair this widget reported upward. Incoming values equal to it
  /// are this widget's own echo and must not re-seed the fields, or the
  /// caret jumps while the diver is still typing.
  double? _reportedLatitude;
  double? _reportedLongitude;

  /// Set while re-seeding so the controller listeners do not treat a
  /// programmatic write as a user edit.
  bool _seeding = false;

  /// Whether every sub-field was empty at the last report.
  bool _isBlank = true;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(CoordinateInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final formatChanged = oldWidget.format != widget.format;
    final valueChanged =
        widget.latitude != _reportedLatitude ||
        widget.longitude != _reportedLongitude;
    if (!formatChanged && !valueChanged) return;

    // Writing a controller that a TextFormField is bound to notifies the
    // ancestor Form, which rebuilds itself. Doing that straight from
    // didUpdateWidget is a setState during build, so re-seed after the frame.
    // initState is safe because no field has bound to the controllers yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _seed();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, () {
        final controller = TextEditingController();
        controller.addListener(() {
          if (!_seeding) _recompute(key);
        });
        return controller;
      });

  void _set(String key, String text) {
    final controller = _controller(key);
    if (controller.text != text) controller.text = text;
  }

  /// The format actually used for seeding and layout.
  ///
  /// UTM and MGRS are undefined beyond 84 N / 80 S. A polar coordinate shown
  /// in a grid layout would render as empty fields -- the position would look
  /// missing, and the next edit would report it away -- so grid formats
  /// degrade to decimal degrees there, matching what the display formatter
  /// already does. With no coordinate yet there is nothing to degrade, so the
  /// chosen layout stands.
  CoordinateFormat _effectiveFormat(double? lat, double? lon) {
    if (!widget.format.isGridFormat) return widget.format;
    if (lat == null || lon == null) return widget.format;
    if (latLngToUtm(lat, lon) != null) return widget.format;
    return CoordinateFormat.decimalDegrees;
  }

  /// Fills every sub-field from the widget's current decimal-degree values.
  void _seed() {
    _reportedLatitude = widget.latitude;
    _reportedLongitude = widget.longitude;
    _seedFrom(widget.latitude, widget.longitude);
  }

  /// Fills every sub-field from an explicit pair.
  ///
  /// The paste path seeds from the parsed values rather than from
  /// [widget.latitude]/[widget.longitude]: the parent owns the coordinate but
  /// deliberately does not rebuild this widget on every keystroke, so those
  /// still hold the previous value and re-seeding from them would wipe what
  /// was just pasted.
  void _seedFrom(double? lat, double? lon) {
    _seeding = true;
    final hasPair = lat != null && lon != null;

    switch (_effectiveFormat(lat, lon)) {
      case CoordinateFormat.decimalDegrees:
        _set('lat', lat == null ? '' : lat.toStringAsFixed(6));
        _set('lon', lon == null ? '' : lon.toStringAsFixed(6));

      case CoordinateFormat.degreesDecimalMinutes:
        _seedDegreeParts(lat, isLatitude: true, withSeconds: false);
        _seedDegreeParts(lon, isLatitude: false, withSeconds: false);

      case CoordinateFormat.degreesMinutesSeconds:
        _seedDegreeParts(lat, isLatitude: true, withSeconds: true);
        _seedDegreeParts(lon, isLatitude: false, withSeconds: true);

      case CoordinateFormat.utm:
        final utm = hasPair ? latLngToUtm(lat, lon) : null;
        _set('zone', utm == null ? '' : '${utm.zone}${utm.band}');
        _set('easting', utm == null ? '' : utm.easting.round().toString());
        _set('northing', utm == null ? '' : utm.northing.round().toString());

      case CoordinateFormat.mgrs:
        final grid = hasPair ? latLngToMgrs(lat, lon) : null;
        _set('grid', grid ?? '');
    }

    _seeding = false;
  }

  void _seedDegreeParts(
    double? value, {
    required bool isLatitude,
    required bool withSeconds,
  }) {
    final prefix = isLatitude ? 'lat' : 'lon';
    if (value == null) {
      _set('${prefix}Deg', '');
      _set('${prefix}Min', '');
      if (withSeconds) _set('${prefix}Sec', '');
      return;
    }

    final hemisphere = hemisphereFor(value, isLatitude: isLatitude);
    if (isLatitude) {
      _latHemisphere = hemisphere;
    } else {
      _lonHemisphere = hemisphere;
    }

    // Shared with the display formatter so both apply the same carry. Doing
    // the arithmetic here independently is what let seconds render as "60.0",
    // which the parser then rejects.
    if (withSeconds) {
      final parts = axisAsDegreesMinutesSeconds(value, isLatitude: isLatitude);
      _set('${prefix}Deg', parts.degrees.toString());
      _set('${prefix}Min', parts.minutes.toString().padLeft(2, '0'));
      _set(
        '${prefix}Sec',
        parts.seconds.toStringAsFixed(degreesMinutesSecondsPrecision),
      );
    } else {
      final parts = axisAsDegreesDecimalMinutes(value, isLatitude: isLatitude);
      _set('${prefix}Deg', parts.degrees.toString());
      _set(
        '${prefix}Min',
        parts.minutes.toStringAsFixed(degreesDecimalMinutesPrecision),
      );
    }
  }

  /// Recomputes the decimal-degree pair from the current sub-fields and
  /// reports it upward.
  void _recompute(String editedKey) {
    // A full coordinate pasted into any single field wins, whatever the
    // active format. Text arrives from dive guides, messages and chartplotter
    // screens in whatever notation its author used, and refusing it because
    // it is not the selected format would be hostile.
    final pasted = parseCoordinates(_controller(editedKey).text);
    if (pasted != null) {
      _report(pasted.latitude, pasted.longitude);
      // Seed from what was parsed, not from the parent's stale values, and
      // leave the reported pair alone: it is the last thing emitted.
      _seedFrom(pasted.latitude, pasted.longitude);
      return;
    }

    switch (_effectiveFormat(_reportedLatitude, _reportedLongitude)) {
      case CoordinateFormat.decimalDegrees:
        _report(
          parseSingleAxis(_controller('lat').text, isLatitude: true),
          parseSingleAxis(_controller('lon').text, isLatitude: false),
        );

      case CoordinateFormat.degreesDecimalMinutes:
        _report(
          _axisFromParts(isLatitude: true, withSeconds: false),
          _axisFromParts(isLatitude: false, withSeconds: false),
        );

      case CoordinateFormat.degreesMinutesSeconds:
        _report(
          _axisFromParts(isLatitude: true, withSeconds: true),
          _axisFromParts(isLatitude: false, withSeconds: true),
        );

      case CoordinateFormat.utm:
        final zone = _controller('zone').text.trim();
        final easting = _controller('easting').text.trim();
        final northing = _controller('northing').text.trim();
        final parsed = parseCoordinates('$zone $easting $northing');
        _report(parsed?.latitude, parsed?.longitude);

      case CoordinateFormat.mgrs:
        final parsed = mgrsToLatLng(_controller('grid').text.trim());
        _report(parsed?.latitude, parsed?.longitude);
    }
  }

  double? _axisFromParts({
    required bool isLatitude,
    required bool withSeconds,
  }) {
    final prefix = isLatitude ? 'lat' : 'lon';
    final degrees = _controller('${prefix}Deg').text.trim();
    if (degrees.isEmpty) return null;
    final minutes = _controller('${prefix}Min').text.trim();
    final seconds = withSeconds ? _controller('${prefix}Sec').text.trim() : '';
    final hemisphere = isLatitude ? _latHemisphere : _lonHemisphere;
    return parseSingleAxis(
      '$degrees ${minutes.isEmpty ? '0' : minutes} '
      '${seconds.isEmpty ? '0' : seconds} $hemisphere',
      isLatitude: isLatitude,
    );
  }

  void _report(double? latitude, double? longitude) {
    // Half a coordinate is not a position: report nothing rather than let a
    // partially typed entry look like a saved one.
    final complete = latitude != null && longitude != null;
    _reportedLatitude = complete ? latitude : null;
    _reportedLongitude = complete ? longitude : null;
    _isBlank = _allFieldsEmpty();
    widget.onChanged(
      CoordinateInputValue(
        latitude: _reportedLatitude,
        longitude: _reportedLongitude,
        isBlank: _isBlank,
      ),
    );
  }

  /// True when nothing is typed in any visible sub-field.
  bool _allFieldsEmpty() =>
      _controllers.values.every((c) => c.text.trim().isEmpty);

  /// The message shown, and used to fail validation, while the entry is
  /// neither blank nor a valid position.
  String? _invalidError() {
    if (_isBlank) return null;
    if (_reportedLatitude != null && _reportedLongitude != null) return null;
    return widget.invalidMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._fieldsForFormat(context),
          if (widget.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _fieldsForFormat(BuildContext context) {
    switch (_effectiveFormat(widget.latitude, widget.longitude)) {
      case CoordinateFormat.decimalDegrees:
        return [
          _field(
            'lat',
            widget.latitudeLabel ?? 'Latitude',
            signed: true,
            carriesError: true,
          ),
          const SizedBox(height: 8),
          _field('lon', widget.longitudeLabel ?? 'Longitude', signed: true),
        ];

      case CoordinateFormat.degreesDecimalMinutes:
        return [
          _degreeRow(
            widget.latitudeLabel ?? 'Latitude',
            isLatitude: true,
            withSeconds: false,
          ),
          const SizedBox(height: 8),
          _degreeRow(
            widget.longitudeLabel ?? 'Longitude',
            isLatitude: false,
            withSeconds: false,
          ),
        ];

      case CoordinateFormat.degreesMinutesSeconds:
        return [
          _degreeRow(
            widget.latitudeLabel ?? 'Latitude',
            isLatitude: true,
            withSeconds: true,
          ),
          const SizedBox(height: 8),
          _degreeRow(
            widget.longitudeLabel ?? 'Longitude',
            isLatitude: false,
            withSeconds: true,
          ),
        ];

      case CoordinateFormat.utm:
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: _field('zone', 'Zone', carriesError: true),
              ),
              const SizedBox(width: 8),
              Expanded(child: _field('easting', 'Easting', numeric: true)),
              const SizedBox(width: 8),
              Expanded(child: _field('northing', 'Northing', numeric: true)),
            ],
          ),
        ];

      case CoordinateFormat.mgrs:
        return [_field('grid', 'Grid reference', carriesError: true)];
    }
  }

  Widget _degreeRow(
    String label, {
    required bool isLatitude,
    required bool withSeconds,
  }) {
    final prefix = isLatitude ? 'lat' : 'lon';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _field('${prefix}Deg', label, numeric: true, suffix: '°'),
        ),
        const SizedBox(width: 8),
        Expanded(child: _field('${prefix}Min', '', numeric: true, suffix: "'")),
        if (withSeconds) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _field('${prefix}Sec', '', numeric: true, suffix: '"'),
          ),
        ],
        const SizedBox(width: 8),
        _hemisphereSelector(isLatitude: isLatitude),
      ],
    );
  }

  Widget _hemisphereSelector({required bool isLatitude}) {
    final options = isLatitude ? ['N', 'S'] : ['E', 'W'];
    final value = isLatitude ? _latHemisphere : _lonHemisphere;
    return DropdownButton<String>(
      value: options.contains(value) ? value : options.first,
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (selected) {
        if (selected == null) return;
        setState(() {
          if (isLatitude) {
            _latHemisphere = selected;
          } else {
            _lonHemisphere = selected;
          }
        });
        _recompute(isLatitude ? 'latDeg' : 'lonDeg');
      },
    );
  }

  Widget _field(
    String key,
    String label, {
    bool numeric = false,
    bool signed = false,
    String? suffix,
    bool carriesError = false,
  }) {
    return TextFormField(
      controller: _controller(key),
      keyboardType: numeric || signed
          ? TextInputType.numberWithOptions(decimal: true, signed: signed)
          : TextInputType.text,
      // Only one field carries the message: the group is validated as a
      // whole, and repeating it under six sub-fields would be noise. Having
      // any validator fail is what stops the form saving.
      validator: carriesError ? (_) => _invalidError() : null,
      autovalidateMode: carriesError
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        suffixText: suffix,
        isDense: true,
      ),
    );
  }
}
