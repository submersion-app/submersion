/// The app's enumerations.
///
/// Split in two so the browser's database worker, which registers the SQL
/// functions and is compiled apart from Flutter, can import `app_enums.dart`
/// alone: `certification_enums.dart` reaches `dart:ui` for its colours.
library;

export 'app_enums.dart';
export 'certification_enums.dart';
