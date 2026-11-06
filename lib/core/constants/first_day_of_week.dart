/// The day a week starts on wherever the app lays out a week: the Day of
/// Week chart, the weekday filter, weekly trend buckets and the date pickers
/// (issue #4232).
///
/// Stored by name in `diver_settings.first_day_of_week`.
enum FirstDayOfWeek {
  /// Follow the device's region, the way CLDR assigns a first day to each
  /// territory.
  auto,
  monday,
  sunday,
  saturday,
}

/// The first day of the week in [DateTime.weekday] numbering (1 = Monday ..
/// 7 = Sunday), or null when [setting] is [FirstDayOfWeek.auto] and the
/// device names no region, so the caller keeps the language's own default.
///
/// [regionCode] is an ISO 3166 country code such as `CH` or `US`; case does
/// not matter.
int? resolveFirstWeekday(FirstDayOfWeek setting, String? regionCode) {
  return switch (setting) {
    FirstDayOfWeek.monday => DateTime.monday,
    FirstDayOfWeek.sunday => DateTime.sunday,
    FirstDayOfWeek.saturday => DateTime.saturday,
    FirstDayOfWeek.auto => firstWeekdayForRegion(regionCode),
  };
}

/// The first day of the week CLDR assigns to [regionCode], or null when
/// there is no region to look up. A region CLDR does not list starts on
/// Monday, its world default (`001`) and the ISO 8601 week.
///
/// The day is a property of the region, not of the language: English starts
/// on Sunday in the US and on Monday in Great Britain, Portuguese on Sunday
/// in Brazil and on Monday in Angola.
int? firstWeekdayForRegion(String? regionCode) {
  if (regionCode == null || regionCode.isEmpty) return null;
  final region = regionCode.toUpperCase();
  if (_sundayRegions.contains(region)) return DateTime.sunday;
  if (_saturdayRegions.contains(region)) return DateTime.saturday;
  if (_fridayRegions.contains(region)) return DateTime.friday;
  return DateTime.monday;
}

/// Unicode CLDR supplemental week data, `firstDay day="sun"`.
const Set<String> _sundayRegions = {
  'AG', 'AS', 'BD', 'BR', 'BS', 'BT', 'BW', 'BZ', 'CA', 'CO', 'DM', 'DO', //
  'ET', 'GT', 'GU', 'HK', 'HN', 'ID', 'IL', 'IN', 'JM', 'JP', 'KE', 'KH', //
  'KR', 'LA', 'MH', 'MM', 'MO', 'MT', 'MX', 'MZ', 'NI', 'NP', 'PA', 'PE', //
  'PH', 'PK', 'PR', 'PT', 'PY', 'SA', 'SG', 'SV', 'TH', 'TT', 'TW', 'UM', //
  'US', 'VE', 'VI', 'WS', 'YE', 'ZA', 'ZW',
};

/// Unicode CLDR supplemental week data, `firstDay day="sat"`.
const Set<String> _saturdayRegions = {
  'AE', 'AF', 'BH', 'DJ', 'DZ', 'EG', 'IQ', 'IR', 'JO', 'KW', 'LY', 'OM', //
  'QA', 'SD', 'SY',
};

/// Unicode CLDR supplemental week data, `firstDay day="fri"`.
const Set<String> _fridayRegions = {'MV'};

/// [weekday] (in [DateTime.weekday] numbering) as a
/// `MaterialLocalizations.firstDayOfWeekIndex`, which counts 0 = Sunday ..
/// 6 = Saturday.
int materialWeekdayIndex(int weekday) => weekday % 7;

/// The inverse of [materialWeekdayIndex].
int weekdayFromMaterialIndex(int index) => index == 0 ? DateTime.sunday : index;

/// The seven weekdays in [DateTime.weekday] numbering, starting at
/// [firstWeekday].
List<int> weekdaysFrom(int firstWeekday) =>
    List.generate(7, (i) => (firstWeekday - 1 + i) % 7 + 1, growable: false);
