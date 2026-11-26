import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The id of [diverId]'s cover for [speciesId] (issue #5027). Derived, so two
/// devices choosing a cover write the same row and sync keeps the newer.
String speciesCoverId(String diverId, String speciesId) =>
    'sc_${sha1.convert(utf8.encode('$diverId|$speciesId'))}';

/// The id of [diverId]'s practice record for [speciesId], derived for the
/// same reason as [speciesCoverId].
String speciesPracticeId(String diverId, String speciesId) =>
    'spr_${sha1.convert(utf8.encode('$diverId|$speciesId'))}';
