import 'package:flutter/material.dart';

import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/shared/widgets/forms/coordinate_input.dart';

/// Bridges a [CoordinateInput] to the pair of decimal-degree
/// [TextEditingController]s the edit forms already keep.
///
/// The forms store, validate, merge, and save coordinates as decimal-degree
/// text. Keeping that as the single source of truth means the notation the
/// diver types in is purely a rendering concern: the save path, the
/// validators, the altitude lookup, and the merge-candidate comparison all
/// carry on reading the same decimal text they always have, whichever format
/// is on screen.
class CoordinateFieldGroup extends StatefulWidget {
  const CoordinateFieldGroup({
    super.key,
    required this.latitudeController,
    required this.longitudeController,
    required this.format,
    this.latitudeLabel,
    this.longitudeLabel,
    this.errorText,
    this.invalidMessage,
  });

  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final CoordinateFormat format;
  final String? latitudeLabel;
  final String? longitudeLabel;
  final String? errorText;

  /// Shown, and used to fail form validation, while the entry is invalid.
  final String? invalidMessage;

  @override
  State<CoordinateFieldGroup> createState() => _CoordinateFieldGroupState();
}

class _CoordinateFieldGroupState extends State<CoordinateFieldGroup> {
  double? _latitude;
  double? _longitude;

  /// Set while this widget writes the controllers, so its own writes are not
  /// mistaken for an external change and bounced back into the input.
  bool _writingBack = false;

  @override
  void initState() {
    super.initState();
    // Assign directly rather than going through _readFromControllers: that
    // path calls setState, which during mounting marks the ancestor Form
    // dirty mid-build.
    _latitude = double.tryParse(widget.latitudeController.text.trim());
    _longitude = double.tryParse(widget.longitudeController.text.trim());
    widget.latitudeController.addListener(_readFromControllers);
    widget.longitudeController.addListener(_readFromControllers);
  }

  @override
  void dispose() {
    widget.latitudeController.removeListener(_readFromControllers);
    widget.longitudeController.removeListener(_readFromControllers);
    super.dispose();
  }

  void _readFromControllers() {
    if (_writingBack || !mounted) return;
    final latitude = double.tryParse(widget.latitudeController.text.trim());
    final longitude = double.tryParse(widget.longitudeController.text.trim());
    if (latitude == _latitude && longitude == _longitude) return;
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
    });
  }

  void _onChanged(CoordinateInputValue value) {
    // An entry that is neither blank nor a position is a typo or a half-typed
    // coordinate. Writing it through as empty would destroy the stored
    // position -- and because the form's range validators treat empty as "no
    // coordinate", nothing downstream would object. Leave the controllers
    // alone; CoordinateInput fails validation so the form cannot be saved in
    // this state.
    if (value.isInvalid) return;

    _writingBack = true;
    widget.latitudeController.text = value.latitude == null
        ? ''
        : value.latitude!.toStringAsFixed(6);
    widget.longitudeController.text = value.longitude == null
        ? ''
        : value.longitude!.toStringAsFixed(6);
    _writingBack = false;
    // Deliberately not setState: the input owns the text the diver is typing,
    // and re-seeding it here would move the caret mid-edit.
    _latitude = value.latitude;
    _longitude = value.longitude;
  }

  @override
  Widget build(BuildContext context) {
    return CoordinateInput(
      format: widget.format,
      latitude: _latitude,
      longitude: _longitude,
      onChanged: _onChanged,
      latitudeLabel: widget.latitudeLabel,
      longitudeLabel: widget.longitudeLabel,
      errorText: widget.errorText,
      invalidMessage: widget.invalidMessage,
    );
  }
}
