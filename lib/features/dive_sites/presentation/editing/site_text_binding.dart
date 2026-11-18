import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// A free-text row of a site bound to [field]: blank is no value, and the
/// text is kept trimmed of the space around it (issue #4527, phase 2).
/// [apply] writes a typed value in place of a plain `set`, for a value that
/// moves another, as a typed country moves its code.
FieldTextBinding<DiveSite, String?> siteWordsBinding(
  EditSession<DiveSite> session,
  EditField<DiveSite, String?> field, {
  void Function(String? value)? apply,
}) => FieldTextBinding<DiveSite, String?>(
  session: session,
  field: field,
  format: (value) => value ?? '',
  parse: (text) => FieldValue(trimmedOrNull(text)),
  apply: apply,
);
