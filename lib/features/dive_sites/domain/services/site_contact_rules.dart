import 'package:submersion/core/util/web_link.dart';

/// What a site's contact details may hold (issue #5073), shared by the
/// Contact card's editor and agent writes.

final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Whether [text] can be a site's email address: blank, or one address.
bool isValidSiteEmail(String? text) {
  final value = text?.trim() ?? '';
  return value.isEmpty || _emailShape.hasMatch(value);
}

/// Whether [text] can be a site's website: blank, or a web address that
/// `parseWebLink` will open.
bool isValidSiteWebsite(String? text) {
  final value = text?.trim() ?? '';
  return value.isEmpty || parseWebLink(value) != null;
}
